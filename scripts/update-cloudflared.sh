#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [ "$OS" = darwin ]; then macos_tool "${BASH_SOURCE[0]}" "$@"; exit $?; fi

REPO="cloudflare/cloudflared"
DEST="$HOME/.local/bin/cloudflared"
ASSET="cloudflared-linux-amd64"
BASE="https://github.com/$REPO/releases/latest/download"

cleanup() {
    log_clean "Removing cloudflared..."
    remove_paths "$DEST"
    log_done "cloudflared removed."
}
dispatch_remove "$@"

log_search "Fetching the latest cloudflared version..."
LATEST=$(fetch "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name')
if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
    log_error "Could not determine the latest cloudflared version."
    exit 1
fi
log_found "Latest version found: $LATEST"

INSTALLED=$(command -v cloudflared >/dev/null 2>&1 \
    && cloudflared --version 2>/dev/null | grep -oE '[0-9]{4}\.[0-9]+\.[0-9]+' | head -1 || true)
version_gate "cloudflared" "$INSTALLED" "$LATEST" && exit 0

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log_download "Downloading $ASSET..."
download "$BASE/$ASSET" "$TMPDIR/cloudflared"

log_install "Installing to $DEST..."
ensure_dir "$(dirname "$DEST")"
install -m 0755 "$TMPDIR/cloudflared" "$DEST"

log_done
"$DEST" --version
