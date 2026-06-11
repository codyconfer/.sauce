#! /bin/bash

set -euo pipefail

PKG=lm-studio.AppImage
URL=https://lmstudio.ai/download/latest/linux/x64
APPS=~/.apps
PKGPATH=$APPS/$PKG

mkdir -p $APPS
curl -fL --output $PKGPATH $URL
