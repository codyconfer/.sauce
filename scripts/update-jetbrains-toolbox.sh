#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [ "$OS" = darwin ]; then macos_tool "${BASH_SOURCE[0]}" "$@"; exit $?; fi

APPDIR=$OPT/JetBrains-Toolbox
LAUNCHER=$BIN/jetbrains-toolbox
API="https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release"

cleanup() {
    log_clean "Removing JetBrains Toolbox..."
    remove_paths "$APPDIR" "$LAUNCHER"
    remove_stamp jetbrains-toolbox
    log_done "JetBrains Toolbox removed."
    log_hint "IDEs installed via Toolbox (under ~/.local/share/JetBrains) remain; remove them from within Toolbox or delete that directory."
}
dispatch_remove "$@"

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

if [ -z "${FORCE:-}" ] && [ -d "$APPDIR" ] && [ "$(read_stamp jetbrains-toolbox)" = "$VERSION" ]; then
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

log_install "Installing to $APPDIR..."
ensure_dir "$OPT"
ensure_dir "$BIN"
tar -C "$TMPDIR" -xzf "$TMPDIR/$TARBALL"
SRC=$(find "$TMPDIR" -mindepth 1 -maxdepth 1 -type d -name 'jetbrains-toolbox-*' | head -n1)
if [ -z "$SRC" ] || [ ! -x "$SRC/bin/jetbrains-toolbox" ]; then
    log_error "Could not find the jetbrains-toolbox app directory in the extracted tarball."
    exit 1
fi

rm -rf "$APPDIR"
mv "$SRC" "$APPDIR"
ln -sfn "$APPDIR/bin/jetbrains-toolbox" "$LAUNCHER"

write_stamp jetbrains-toolbox "$VERSION"

log_done
log_hint "Run '$LAUNCHER' (or 'jetbrains-toolbox') to launch the Toolbox app."
