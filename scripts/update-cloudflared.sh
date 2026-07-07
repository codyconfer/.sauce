#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

REPO=cloudflare/cloudflared
DEST="$HOME/.local/bin"
BIN="$DEST/cloudflared"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log_search "Fetching the latest cloudflared version..."
TAG=$(gh release view --repo "$REPO" --json tagName --jq '.tagName')
if [ -z "$TAG" ]; then
    log_error "Could not resolve the latest cloudflared tag."
    exit 1
fi
log_found "Latest version found: $TAG"

INSTALLED=$([ -x "$BIN" ] && "$BIN" --version 2>/dev/null | awk '{print $3}' || true)
version_gate "cloudflared" "$INSTALLED" "$TAG" && exit 0

URL="https://github.com/$REPO/releases/download/$TAG/cloudflared-linux-amd64"
log_download "Downloading cloudflared $TAG..."
download "$URL" "$TMPDIR/cloudflared"

log_install "Installing to $DEST..."
ensure_dir "$DEST"
install -m755 "$TMPDIR/cloudflared" "$BIN"

log_done
"$BIN" --version
