#! /bin/bash

set -euo pipefail

PKG=obsidian.AppImage
REPO=obsidianmd/obsidian-releases
APPS=~/.apps
PKGPATH=$APPS/$PKG

ASSET=$(gh release view --repo $REPO --json assets \
  --jq '.assets[].name | select(endswith(".AppImage")) | select(contains("arm64") | not)' \
  | head -n1)

mkdir -p $APPS
gh release download --repo $REPO --pattern "$ASSET" --output $PKGPATH --clobber
chmod +x $PKGPATH
