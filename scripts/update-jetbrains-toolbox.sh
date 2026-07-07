#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

BIN=$APPS/jetbrains-toolbox
API="https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release"

log_search "Fetching the latest JetBrains Toolbox version..."
META=$(fetch "$API")
VERSION=$(echo "$META" | jq -r '.TBA[0].version')
URL=$(echo "$META" | jq -r '.TBA[0].downloads.linux.link')
CSURL=$(echo "$META" | jq -r '.TBA[0].downloads.linux.checksumLink')
if [ -z "$URL" ] || [ "$URL" = "null" ]; then
    log_error "Could not resolve JetBrains Toolbox download URL."
    exit 1
fi
log_found "Latest version found: $VERSION"

if [ -z "${FORCE:-}" ] && [ -f "$BIN" ] && [ "$(read_stamp jetbrains-toolbox)" = "$VERSION" ]; then
    log_done "JetBrains Toolbox $VERSION is already installed — skipping. (set FORCE=1 to reinstall)"
    exit 0
fi

TARBALL=$(basename "$URL")
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log_download "Downloading $TARBALL..."
download "$URL" "$TMPDIR/$TARBALL"

SHA=$(fetch "$CSURL" | cut -d' ' -f1)
verify_sha256 "$SHA" "$TMPDIR/$TARBALL"

log_install "Installing to $APPS..."
ensure_dir "$APPS"
tar -C "$TMPDIR" -xzf "$TMPDIR/$TARBALL"
SRC=$(find "$TMPDIR" -maxdepth 2 -name jetbrains-toolbox -type f | head -n1)
install -Dm755 "$SRC" "$BIN"

write_stamp jetbrains-toolbox "$VERSION"

log_done
log_hint "Run '$BIN' to launch the Toolbox app."
