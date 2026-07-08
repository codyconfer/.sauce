#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DEST="$HOME/.local/bin/bw"

log_search "Fetching the latest Bitwarden CLI version..."
LATEST=$(fetch "https://registry.npmjs.org/@bitwarden/cli/latest" | jq -r '.version')
if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
    log_error "Could not determine the latest Bitwarden CLI version."
    exit 1
fi
log_found "Latest version found: $LATEST"

INSTALLED=$(command -v bw >/dev/null 2>&1 && bw --version 2>/dev/null | head -1 || true)
version_gate "Bitwarden CLI" "$INSTALLED" "$LATEST" && exit 0

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

ZIP="bw-linux-${LATEST}.zip"
URL="https://github.com/bitwarden/clients/releases/download/cli-v${LATEST}/${ZIP}"

log_download "Downloading $ZIP..."
download "$URL" "$TMPDIR/$ZIP"

log_install "Installing to $DEST..."
unzip -o -q "$TMPDIR/$ZIP" bw -d "$TMPDIR"
ensure_dir "$(dirname "$DEST")"
install -m 0755 "$TMPDIR/bw" "$DEST"

log_done
"$DEST" --version
