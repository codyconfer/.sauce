#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

APPIMAGE="$BIN/cursor.AppImage"
API="https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable"

cleanup() {
    log_clean "Removing Cursor..."
    remove_paths "$APPIMAGE" "$ICONS/cursor.png"
    remove_stamp cursor
    log_done "Cursor removed."
    log_hint "The .desktop launcher is chezmoi-managed — deselect 'cursor' from the tools prompt and re-apply to remove it."
}
dispatch_remove "$@"

log_search "Fetching the latest Cursor version..."
META=$(fetch "$API")
VERSION=$(echo "$META" | jq -r '.version')
URL=$(echo "$META" | jq -r '.downloadUrl')
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ] || [ -z "$URL" ] || [ "$URL" = "null" ]; then
    log_error "Could not resolve the latest Cursor AppImage."
    exit 1
fi
log_found "Latest version found: $VERSION"

# The AppImage has no version flag; compare against the last install.
if [ -z "${FORCE:-}" ] && [ -f "$APPIMAGE" ] && [ "$(read_stamp cursor)" = "$VERSION" ]; then
    log_done "Cursor $VERSION is already installed — skipping. (set FORCE=1 to reinstall)"
    exit 0
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log_download "Downloading Cursor $VERSION..."
download_with_headers "$URL" "$TMPDIR/cursor.AppImage" "$TMPDIR/headers"
verify_md5_etag "$TMPDIR/headers" "$TMPDIR/cursor.AppImage"

log_install "Installing to $APPIMAGE..."
ensure_dir "$BIN"
chmod +x "$TMPDIR/cursor.AppImage"
mv "$TMPDIR/cursor.AppImage" "$APPIMAGE"
write_stamp cursor "$VERSION"

extract_appimage_icon "$APPIMAGE" "$ICONS/cursor.png" || true

log_done
log_hint "Launch Cursor from your app menu or run '$APPIMAGE'."
