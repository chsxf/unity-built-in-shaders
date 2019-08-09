
# Unity Built-in Shaders

This repository contains built-in shader code for all release of Unity back to Unity 3.
It is useful to compare changes between versions and keep up to date versions of Unity's own shaders (you do not need to download the code from Unity's website anymore!)

## Exceptions

Only fully released versions of Unity are taken into account. Releases from the Alpha, Beta or Patch channels are not considered.

# Repository Navigation

You can access shader code through:

* Branches to access all minor releases inside a major version and stay up-to-date (2017.2, 2018.3, ...)
* Tags to access a specific version (v2017.4.1f1, v2019.1.5f1, ...)

## Master branch

Master will always be synced with the latest main stream release. 

Please note that LTS releases are never merged with master.

# Automatic Updater

Run `node check-unity-version.js` to update the repository automatically with the new versions.

## Exception

* `master` must be merged manually with the main-stream branch

## Requirements

* **Node.js version v10.x or later** (should probably work with earlier versions, but has not been tested)
* **bash** in order to execute `add-version.sh` script

# License

See [license.txt](license.txt)
