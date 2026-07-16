#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [ "$OS" = darwin ]; then macos_tool "${BASH_SOURCE[0]}" "$@"; exit $?; fi

APPIMAGE="$BIN/lm-studio.AppImage"
URL="https://lmstudio.ai/download/latest/linux/x64"

cleanup() {
    log_clean "Removing LM Studio..."
    remove_paths "$APPIMAGE" "$ICONS/lm-studio.png"
    remove_stamp lm-studio
    log_done "LM Studio removed."
    log_hint "The .desktop launcher is chezmoi-managed — deselect 'lmstudio' from the GUI apps prompt and re-apply to remove it."
}
dispatch_remove "$@"

log_search "Fetching the latest LM Studio version..."
FINAL=$(curl -fsIL -o /dev/null -w '%{url_effective}' "$URL")
VERSION=$(echo "$FINAL" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?' | head -n1)
if [ -z "$VERSION" ]; then
    log_error "Could not resolve LM Studio version from $FINAL"
    exit 1
fi
log_found "Latest version found: $VERSION"

if [ -z "${FORCE:-}" ] && [ -f "$APPIMAGE" ] && [ "$(read_stamp lm-studio)" = "$VERSION" ]; then
    log_done "LM Studio $VERSION is already installed — skipping. (set FORCE=1 to reinstall)"
    exit 0
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log_download "Downloading LM Studio $VERSION..."
download_with_headers "$URL" "$TMPDIR/lm-studio.AppImage" "$TMPDIR/headers"
verify_md5_etag "$TMPDIR/headers" "$TMPDIR/lm-studio.AppImage"

log_install "Installing to $APPIMAGE..."
ensure_dir "$BIN"
chmod +x "$TMPDIR/lm-studio.AppImage"
mv "$TMPDIR/lm-studio.AppImage" "$APPIMAGE"
write_stamp lm-studio "$VERSION"

extract_appimage_icon "$APPIMAGE" "$ICONS/lm-studio.png" || true

log_done
log_hint "Launch LM Studio from your app menu or run '$APPIMAGE'."
