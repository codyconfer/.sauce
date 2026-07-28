#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [ "$OS" = darwin ]; then macos_tool "${BASH_SOURCE[0]}" "$@"; exit $?; fi

REPO="tmux/tmux"
DEST="$OPT/tmux"

cleanup() {
    log_clean "Removing tmux..."
    remove_paths "$DEST" "$BIN/tmux"
    log_done "tmux removed."
    log_hint "Build dependencies (libevent/ncurses headers) and ~/.config/tmux were left in place."
}
dispatch_remove "$@"

log_search "Fetching the latest tmux version..."
LATEST=$(fetch "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name')
if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
    log_error "Could not determine the latest tmux version."
    exit 1
fi
log_found "Latest version found: $LATEST"

INSTALLED=$([ -x "$DEST/bin/tmux" ] && "$DEST/bin/tmux" -V | awk '{print $2}' || true)
version_gate "tmux" "$INSTALLED" "$LATEST" && exit 0

# tmux ships source tarballs only — the compiler comes from the essential packages,
# libevent/ncurses headers do not.
log_install "Installing build dependencies..."
case "$(detect_family)" in
    debian) install_pkgs libevent-dev libncurses-dev pkg-config || log_warn "dependency install failed." ;;
    fedora) install_pkgs libevent-devel ncurses-devel pkgconf-pkg-config || log_warn "dependency install failed." ;;
    arch)   install_pkgs libevent ncurses pkgconf || log_warn "dependency install failed." ;;
    *) log_error "unsupported distro (need apt, dnf, or pacman)."; exit 1 ;;
esac

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

TARBALL="tmux-$LATEST.tar.gz"
log_download "Downloading $TARBALL..."
download "https://github.com/$REPO/releases/download/$LATEST/$TARBALL" "$TMPDIR/$TARBALL"

SRC="$TMPDIR/tmux-$LATEST"
log_install "Building tmux $LATEST (takes a minute)..."
tar -C "$TMPDIR" -xzf "$TMPDIR/$TARBALL"
( cd "$SRC" && ./configure --prefix="$DEST" >/dev/null )
make -C "$SRC" -j"$(nproc 2>/dev/null || echo 2)" >/dev/null

log_install "Installing to $DEST..."
rm -rf "$DEST"
ensure_dir "$DEST"
make -C "$SRC" install >/dev/null

ensure_dir "$BIN"
ln -sf "$DEST/bin/tmux" "$BIN/tmux"
log_link "Linked tmux -> $BIN/tmux"

log_done
"$DEST/bin/tmux" -V
log_hint "tmux is symlinked into ~/.local/bin (on PATH via your rc files)."
