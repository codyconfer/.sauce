#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

APPIMAGE="$BIN/obsidian.AppImage"
API="https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest"

cleanup() {
    log_clean "Removing Obsidian..."
    remove_paths "$APPIMAGE" "$ICONS/obsidian.png"
    remove_stamp obsidian
    log_done "Obsidian removed."
    log_hint "The .desktop launcher is chezmoi-managed — deselect 'obsidian' from the tools prompt and re-apply to remove it."
}
dispatch_remove "$@"

log_search "Fetching the latest Obsidian version..."
META=$(fetch "$API")
VERSION=$(echo "$META" | jq -r '.tag_name')
URL=$(echo "$META" | jq -r '.assets[] | select((.name|endswith(".AppImage")) and (.name|contains("arm64")|not)) | .browser_download_url' | head -n1)
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ] || [ -z "$URL" ]; then
    log_error "Could not resolve the latest Obsidian AppImage."
    exit 1
fi
log_found "Latest version found: $VERSION"

# The AppImage has no version flag; compare against the last install.
if [ -z "${FORCE:-}" ] && [ -f "$APPIMAGE" ] && [ "$(read_stamp obsidian)" = "$VERSION" ]; then
    log_done "Obsidian $VERSION is already installed — skipping. (set FORCE=1 to reinstall)"
    exit 0
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log_download "Downloading Obsidian $VERSION..."
download_with_headers "$URL" "$TMPDIR/obsidian.AppImage" "$TMPDIR/headers"
verify_md5_etag "$TMPDIR/headers" "$TMPDIR/obsidian.AppImage"

log_install "Installing to $APPIMAGE..."
ensure_dir "$BIN"
chmod +x "$TMPDIR/obsidian.AppImage"
mv "$TMPDIR/obsidian.AppImage" "$APPIMAGE"
write_stamp obsidian "$VERSION"

extract_appimage_icon "$APPIMAGE" "$ICONS/obsidian.png" || true

log_done
log_hint "Launch Obsidian from your app menu or run '$APPIMAGE'."
