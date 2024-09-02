// Usage: node check-unity-version.js
var http = require('https');
const { spawn, spawnSync } = require('child_process');
const { exit } = require('process');
const { basename } = require('path');

function dieWithUsage() {
	process.stdout.write("Usage:\n");
	process.stdout.write(`\tnode ${basename(__filename)} [--update] [--version MAJOR.MINOR.PATCH]\n\n`);

	process.stdout.write("\t--update\n\t\tExecute the script and applies the update. Without this parameter, the scripts runs a dry-test only.\n");
	process.stdout.write("\t--version MAJOR.MINOR.PATCH\n\t\tLook for the specified version only\n");
	exit();
}

let applyUpdate = false;
let verboseMode = false;
let specificVersion = undefined;
for (let i = 2; i < process.argv.length; i++) {
	const arg = process.argv[i];
	switch (arg) {
		case '--verbose':
			verboseMode = true;
			break;

		case '--update':
			applyUpdate = true;
			break;

		case '--version':
			let parameterVersionRE = /^(\d+)\.(\d+)\.(\d+f\d+)$/
			let versionParameterIndex = (i + 1);
			let potentialSpecificVersion = process.argv[versionParameterIndex];
			if (specificVersion != undefined || process.argv.length < versionParameterIndex + 1 || !parameterVersionRE.test(potentialSpecificVersion)) {
				dieWithUsage();
			}		
			specificVersion = potentialSpecificVersion;
			i++;
			break;
	}
}

function verboseLog(message, ...params) {
	console.log(message, ...params);
}

function getCommitHash(ref) {
	var result = spawnSync('git', ['rev-parse', ref])
	if (result.status != 0) {
		process.stderr.write(`Unable to get commit hash for ref ${ref}\n`)
		process.exit();
	}
	return result.stdout.trim();
}

process.stdout.write('Updating repository...\n');
spawnSync('git', [ 'fetch', '--all' ]);

var localCommitHash = getCommitHash('master');
verboseLog('Local commit hash: %s', localCommitHash);
var remoteCommitHash = getCommitHash('origin/master');
verboseLog('Remote commit hash: %s', remoteCommitHash);

if (localCommitHash != remoteCommitHash) {
	process.stdout.write(`The local repository is not up-to-date with the remote one.\n(${localCommitHash} vs ${remoteCommitHash})\nPulling the master branch...\n`)
	spawnSync('git', ['pull'])
	process.stdout.write('Done.\n\nPlease restart the script\n');
	process.exit();
}

process.stdout.write('Done\n\n');

if (specificVersion) {
	process.stdout.write(`Running for version ${specificVersion} only\n`);
}
if (applyUpdate) {
 	process.stdout.write("Applying updates\n\n");
}
else {
	process.stdout.write('Dry-run\n\n');
}

var branches = {};

var branchKeys = [];
var currentBranchIndex = -1;
function parseBranches() {
	for (let mainBranch in branches) {
		branchKeys.push(mainBranch);
	}
	parseNextBranch();
}

function parseNextBranch() {
	currentBranchIndex++;
	if (currentBranchIndex >= branchKeys.length) {
		dumpBranches();
	}
	else {
		let branch = branchKeys[currentBranchIndex];
		let versionFilter1 = `v${branch}.${branches[branch].maxVersion}f*`;
		let versionFilter2 = `v${branch}.${branches[branch].maxVersion}`;

		let git = spawn('git', [ 'tag', '-l', versionFilter1, versionFilter2 ]);

		var branchTagData = '';
		git.stdout.on('data', (_data) => {
			branchTagData += _data;
		});
		git.on('close', () => {
			branchTagData = branchTagData.trim();
			branches[branch].isPresent = (branchTagData.length > 0);

			parseNextBranch();
		});
	}
}

function dumpBranches() {
	let updateCount = 0;
	for (let mainBranch in branches) {
		let msg = `${mainBranch}:\t${mainBranch}.${branches[mainBranch].maxVersion}\n`;
		if (!branches[mainBranch].isPresent) {
			updateCount++;
			msg += '\t-> Branch not present\n';
		}
		process.stdout.write(msg);
	}

	if (updateCount == 0) {
		process.stdout.write("\nNo branch to update\n");
	}
	else {
		process.stdout.write(`\n${updateCount} branch(es) to update\n`);
		if (applyUpdate) {
			currentBranchIndex = -1;
			branchKeys = branchKeys.reverse();
			addNextMissingBranch();
		}
	}
}

function addNextMissingBranch() {
	currentBranchIndex++;
	if (currentBranchIndex < branchKeys.length) {
		let branch = branchKeys[currentBranchIndex];
		let branchValues = branches[branch];
		if (!branchValues.isPresent) {
			let version = `${branch}.${branchValues.maxVersion}`;
			process.stdout.write("\n");
			process.stdout.write('--------------------------------------------------\n');
			process.stdout.write(`Updating version '${version}'...\n`);
			process.stdout.write(` -> URL: ${branchValues.url}\n`);
			process.stdout.write('--------------------------------------------------\n');

			let options = { cwd: process.cwd() };
			let addVersionProcess = spawn(`${__dirname}/add-version.sh`, [ branchValues.url ], options);

			addVersionProcess.stdout.on('data', (_data) => {
				process.stdout.write(_data);
			});

			addVersionProcess.on('close', () => {
				addNextMissingBranch();
			});
		}
		else {
			addNextMissingBranch();
		}
	}
}

const downloadBaseURL = 'https://download.unity3d.com/download_unity/[SLUG]/builtin_shaders-[VERSION].zip';
const versionRegex = /f\d+$/;
const urlRegex = /\/([^/]+)$/;
function parsePage(_pageContent) {
	const needle = 'self.__next_f.push';

	const lastIndexOf = _pageContent.lastIndexOf(needle);
	let dataToParse = _pageContent.substring(lastIndexOf + needle.length + 1).trim();
	dataToParse = dataToParse.replace(/\)<\/script><\/body><\/html>$/, '');
	
	const data = JSON.parse(dataToParse);
	let subDataToParse = data[1].replace(/^\d+:/, '');
	const subData = JSON.parse(subDataToParse);
	
	const majorVersionsRoot = subData[3]['children'][3]['versions'];
	for (const majorVersionData of majorVersionsRoot) {
		const allVersions = majorVersionData['releases']['tech'].concat(majorVersionData['releases']['lts'])
		for (const minorVersionData of allVersions) {
			if (['TECH', 'LTS'].indexOf(minorVersionData['stream']) >= 0 && versionRegex.test(minorVersionData['version'])) {
				const considerVersion = (!specificVersion || specificVersion == minorVersionData['version']);
				if (considerVersion) {
					let versionChunks = minorVersionData['version'].split('.');
					let mainBranch = versionChunks[0] + '.' + versionChunks[1];
					let subBranch = parseInt(versionChunks[2]);

					let hasNoBranch = false;
					if (!branches[mainBranch]) {
						branches[mainBranch] = { maxVersion: 0 };
						hasNoBranch = true;
					}

					let currentMaxSubBranch = branches[mainBranch].maxVersion;
					if (currentMaxSubBranch < subBranch || hasNoBranch) {
						branches[mainBranch] = { maxVersion: Math.max(currentMaxSubBranch, subBranch) };

						const urlResult = urlRegex.exec(minorVersionData['unityHubDeepLink'])
						if (urlResult !== null) {
							let url = downloadBaseURL.replace('[SLUG]', urlResult[1]).replace('[VERSION]', minorVersionData['version']);
							branches[mainBranch].url = url;
						}
					}
				}
			}
		}
	}

	parseBranches();
}

let options = {
	host: 'unity.com',
	path: '/releases/editor/archive'
};

var content = '';
var req = http.request(options, (_res) => {
	_res.on('data', (_chunk) => {
		content += _chunk;
	});
	_res.on('end', () => parsePage(content));
});
req.end();
