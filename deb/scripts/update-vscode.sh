#! /bin/bash

set -euo pipefail

PKG=vscode.deb
URL="https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
APPS=~/.apps
PKGPATH=$APPS/$PKG

mkdir -p $APPS
curl -fL --output $PKGPATH $URL
sudo apt install -y $PKGPATH
rm $PKGPATH
