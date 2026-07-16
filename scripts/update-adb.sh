#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [ "$OS" = darwin ]; then macos_tool "${BASH_SOURCE[0]}" "$@"; exit $?; fi

DEST_DIR="$HOME/.local/bin"
URL="https://dl.google.com/android/repository/platform-tools-latest-linux.zip"

cleanup() {
    log_clean "Removing adb + fastboot..."
    remove_paths "$DEST_DIR/adb" "$DEST_DIR/fastboot"
    remove_stamp adb
    log_done "adb + fastboot removed."
}
dispatch_remove "$@"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log_search "Fetching the latest Android platform-tools..."
download "$URL" "$TMPDIR/platform-tools.zip"

REV=$(unzip -p "$TMPDIR/platform-tools.zip" platform-tools/source.properties 2>/dev/null \
    | sed -n 's/^Pkg\.Revision=//p' | tr -d '[:space:]')
log_found "Latest revision found: ${REV:-unknown}"

if [ -z "${FORCE:-}" ] && [ -x "$DEST_DIR/adb" ] && [ -n "$REV" ] && [ "$(read_stamp adb)" = "$REV" ]; then
    log_done "platform-tools $REV is already installed — skipping. (set FORCE=1 to reinstall)"
    exit 0
fi

log_install "Installing adb + fastboot to $DEST_DIR..."
unzip -o -q "$TMPDIR/platform-tools.zip" -d "$TMPDIR"
ensure_dir "$DEST_DIR"
install -m 0755 "$TMPDIR/platform-tools/adb" "$DEST_DIR/adb"
install -m 0755 "$TMPDIR/platform-tools/fastboot" "$DEST_DIR/fastboot"
write_stamp adb "$REV"

log_done
"$DEST_DIR/adb" --version | head -1
