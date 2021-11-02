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
let specificVersion = undefined;
for (let i = 2; i < process.argv.length; i++) {
	const arg = process.argv[i];
	switch (arg) {
		case '--update':
			applyUpdate = true;
			break;

		case '--version':
			let parameterVersionRE = /^(\d+)\.(\d+)\.(\d+)$/
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

process.stdout.write('Updating repository... ');
spawnSync('git', [ 'fetch', '--all' ]);
spawnSync('git', [ 'pull ']);
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

var versionRegex = /\<div class="contextual-links-region clearfix"\>\<h4\>Unity (.+)\<\/h4\>\<\/div\>/g;
var urlRegex = /\<a href="((?:.+)builtin_shaders(?:.+))"\>/g;
function parsePage(_pageContent) {
	let result = versionRegex.exec(_pageContent);
	if (result !== null) {
		let version = result[1];

		const considerVersion = (!specificVersion || specificVersion == version);
		if (considerVersion) {
			let versionChunks = version.split('.');
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

				urlRegex.lastIndex = versionRegex.lastIndex;
				result = urlRegex.exec(_pageContent);
				if (result !== null) {
					branches[mainBranch].url = result[1];
				}
			}
		}

		parsePage(_pageContent);
	}
	else {
		parseBranches();
	}
}

let options = {
	host: 'unity3d.com',
	path: '/get-unity/download/archive'
};

var content = '';
var req = http.request(options, (_res) => {
	_res.on('data', (_chunk) => {
		content += _chunk;
	});
	_res.on('end', () => parsePage(content));
});
req.end();
