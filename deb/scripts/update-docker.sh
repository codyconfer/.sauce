#! /bin/bash

set -euo pipefail

PKG=docker-desktop-amd64.deb
URL=https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb
APPS=~/.apps
PKGPATH=$APPS/$PKG

mkdir -p $APPS
curl -fL --output $PKGPATH $URL
sudo apt install -y $PKGPATH
rm $PKGPATH
