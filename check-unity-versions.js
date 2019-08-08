// Usage: node check-unity-version.js
var http = require('https');
const { spawn } = require('child_process');

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
	for (let mainBranch in branches) {
		let msg = `${mainBranch}:\t${mainBranch}.${branches[mainBranch].maxVersion}\n`;
		if (!branches[mainBranch].isPresent) {
			msg += '\t-> Branch not present\n';
		}
		process.stdout.write(msg);
	}

	currentBranchIndex = -1;
	addNextMissingBranch();
}

function addNextMissingBranch() {
	currentBranchIndex++;
	if (currentBranchIndex < branchKeys.length) {
		let branch = branchKeys[currentBranchIndex];
		let branchValues = branches[branch];
		if (!branchValues.isPresent) {
			let version = `${branch}.${branchValues.maxVersion}`;
			process.stdout.write("\n\n");
			process.stdout.write(`Updating version '${version}'...\n`);
			process.stdout.write(` -> URL: ${branchValues.url}\n`);

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
		let versionChunks = version.split('.');
		let mainBranch = versionChunks[0] + '.' + versionChunks[1];
		let subBranch = parseInt(versionChunks[2]);

		if (!branches[mainBranch]) {
			branches[mainBranch] = { maxVersion: 0 };
		}

		let currentMaxSubBranch = branches[mainBranch].maxVersion;
		if (currentMaxSubBranch < subBranch) {
			branches[mainBranch] = { maxVersion: Math.max(currentMaxSubBranch, subBranch) };

			urlRegex.lastIndex = versionRegex.lastIndex;
			result = urlRegex.exec(_pageContent);
			if (result !== null) {
				branches[mainBranch].url = result[1];
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
