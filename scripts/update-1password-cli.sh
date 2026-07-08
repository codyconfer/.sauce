#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DEST="$HOME/.local/bin/op"
ARCH="amd64"

log_search "Fetching the latest 1Password CLI version..."
# Capture the page first, then extract — piping curl straight into `grep | head`
# trips a broken-pipe (curl exit 23) under `set -o pipefail` once head closes early.
HISTORY=$(fetch "https://app-updates.agilebits.com/product_history/CLI2")
LATEST=$(printf '%s\n' "$HISTORY" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sed -n '1p')
LATEST="${LATEST#v}"
if [ -z "$LATEST" ]; then
    log_error "Could not determine the latest 1Password CLI version."
    exit 1
fi
log_found "Latest version found: v$LATEST"

INSTALLED=$(command -v op >/dev/null 2>&1 && op --version 2>/dev/null | head -1 || true)
version_gate "1Password CLI" "$INSTALLED" "$LATEST" && exit 0

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

ZIP="op_linux_${ARCH}_v${LATEST}.zip"
URL="https://cache.agilebits.com/dist/1P/op2/pkg/v${LATEST}/${ZIP}"

log_download "Downloading $ZIP..."
download "$URL" "$TMPDIR/$ZIP"

log_install "Installing to $DEST..."
unzip -o -q "$TMPDIR/$ZIP" op -d "$TMPDIR"
ensure_dir "$(dirname "$DEST")"
install -m 0755 "$TMPDIR/op" "$DEST"

log_done
"$DEST" --version
