# Proton Community Updater
**Script to download and manage Community Proton builds**

This script is an easy way to download, extract and delete custom Proton Versions from different contributors.
Currently, GloriousEggroll and TKG are implemented, but the list can easily be complemented - and if you want some other Builds to be added by default, just tell me! :)

The script uses Zenity (if its installed) to display a nice GUI, but can be run in CLI-Mode as well, if Zenity is not found.

## Dependencies

- **bash** - obvioulsy 
- **coreutils** - also pretty obvious
- **curl**  - to download the release-lists and the selected versions
- **xz** - to extract the tar.xz archives used by TKG
- **zenity** - optional, for displaying the GUI

## Installation:

From Source:
1. Download it!
2. Run it!
3. If you want, move *proton-community-updater-icon.png* to */usr/share/pixmaps/*

For Arch Linux and derivatives: https://aur.archlinux.org/packages/proton-community-updater/

## Contributors/recognition:
- https://github.com/the-sane/lug-helper for the awesome zenity-"framework"
- https://github.com/flubberding/ProtonUpdater for the initial inspiration and groundwork for downloading
- https://github.com/richardtatum/sc-runner-updater for adding upon flubberdings single-version downloader
