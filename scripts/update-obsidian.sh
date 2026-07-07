#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PKG=obsidian.AppImage
REPO=obsidianmd/obsidian-releases
PKGPATH=$APPS/$PKG

log_search "Fetching the latest Obsidian release..."
ASSET=$(gh release view --repo "$REPO" --json assets \
  --jq '.assets[].name | select(endswith(".AppImage")) | select(contains("arm64") | not)' \
  | head -n1)
if [ -z "$ASSET" ]; then
    log_error "Could not find a linux x64 AppImage asset."
    exit 1
fi
log_found "Latest version found: $ASSET"

if [ -z "${FORCE:-}" ] && [ -f "$PKGPATH" ] && [ "$(read_stamp obsidian)" = "$ASSET" ]; then
    log_done "Obsidian $ASSET is already installed — skipping. (set FORCE=1 to reinstall)"
    exit 0
fi

ensure_dir "$APPS"
log_download "Downloading $ASSET..."
gh release download --repo "$REPO" --pattern "$ASSET" --output "$PKGPATH" --clobber

log_verify "Verifying checksum..."
ACTUAL=$(sha256sum "$PKGPATH" | cut -d' ' -f1)
if [ -n "${OBSIDIAN_SHA256:-}" ]; then
    if [ "$ACTUAL" != "$OBSIDIAN_SHA256" ]; then
        log_error "Checksum mismatch: expected $OBSIDIAN_SHA256, got $ACTUAL"
        rm -f "$PKGPATH"
        exit 1
    fi
    log_done "Checksum OK."
else
    log_info "No upstream checksum for Obsidian. Computed sha256: $ACTUAL"
    echo "    Pin it with: export OBSIDIAN_SHA256=$ACTUAL"
fi

log_install "Making AppImage executable..."
chmod +x "$PKGPATH"

write_stamp obsidian "$ASSET"

APP_NAME="Obsidian" \
APP_COMMENT="Knowledge base on local Markdown files" \
APP_EXEC="$PKGPATH --no-sandbox" \
APP_ICON="obsidian" \
APP_CATEGORIES="Office;Utility;" \
install_desktop_entry obsidian

log_done
