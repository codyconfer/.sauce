#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DEST="$OPT/nvim"
TARBALL="nvim-linux-x86_64.tar.gz"
URL="https://github.com/neovim/neovim/releases/download/stable/$TARBALL"

cleanup() {
    log_clean "Removing Neovim..."
    remove_paths "$DEST" "$BIN/nvim"
    log_done "Neovim removed."
}
dispatch_remove "$@"

log_search "Fetching the latest Neovim (stable) version..."
LATEST=$(fetch "https://api.github.com/repos/neovim/neovim/releases/tags/stable" \
    | jq -r '.body' | grep -oE 'NVIM v[0-9.]+' | head -n1 | awk '{print $2}')
if [ -z "$LATEST" ]; then
    log_error "Could not determine the latest Neovim version."
    exit 1
fi
log_found "Latest version found: $LATEST"

INSTALLED=$([ -x "$DEST/bin/nvim" ] && "$DEST/bin/nvim" --version | head -n1 | awk '{print $2}' || true)
version_gate "Neovim" "$INSTALLED" "$LATEST" && exit 0

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log_download "Downloading $TARBALL..."
download "$URL" "$TMPDIR/$TARBALL"

log_install "Installing to $DEST..."
rm -rf "$DEST"
ensure_dir "$DEST"
tar -C "$DEST" --strip-components=1 -xzf "$TMPDIR/$TARBALL"

ensure_dir "$BIN"
ln -sf "$DEST/bin/nvim" "$BIN/nvim"
log_link "Linked nvim -> $BIN/nvim"

log_done
"$DEST/bin/nvim" --version | head -n1
log_hint "nvim is symlinked into ~/.local/bin (on PATH via your rc files)."
