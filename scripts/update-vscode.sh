#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

FAMILY=$(detect_family)
case "$FAMILY" in
    debian) PLATFORM=linux-deb-x64 ;;
    fedora) PLATFORM=linux-rpm-x64 ;;
    arch)   PLATFORM=linux-x64 ;;
    *) log_error "unsupported distro (need apt, dnf, or pacman)."; exit 1 ;;
esac
API="https://update.code.visualstudio.com/api/update/$PLATFORM/stable/latest"

cleanup() {
    log_clean "Removing VS Code..."
    if [ "$FAMILY" = "arch" ]; then
        remove_paths "$OPT/vscode" "$BIN/code"
    else
        remove_pkgs code
    fi
    log_done "VS Code removed."
}
dispatch_remove "$@"

log_search "Fetching the latest VS Code version..."
META=$(fetch "$API")
URL=$(echo "$META" | jq -r '.url')
SHA=$(echo "$META" | jq -r '.sha256hash')
VERSION=$(echo "$META" | jq -r '.productVersion')
if [ -z "$URL" ] || [ "$URL" = "null" ] || [ -z "$SHA" ] || [ "$SHA" = "null" ]; then
    log_error "Could not resolve VS Code download URL/checksum."
    exit 1
fi
log_found "Latest version found: $VERSION"

INSTALLED=$(command -v code >/dev/null 2>&1 && code --version 2>/dev/null | head -1 || true)
version_gate "VS Code" "$INSTALLED" "$VERSION" && exit 0

ensure_dir "$CACHE"
PKG=$(basename "$URL")
PKGPATH="$CACHE/$PKG"
log_download "Downloading $PKG..."
download "$URL" "$PKGPATH"

verify_sha256 "$SHA" "$PKGPATH"

log_install "Installing..."
if [ "$FAMILY" = "arch" ]; then
    DEST="$OPT/vscode"
    rm -rf "$DEST"
    ensure_dir "$DEST"
    tar -C "$DEST" --strip-components=1 -xzf "$PKGPATH"
    ensure_dir "$BIN"
    ln -sf "$DEST/bin/code" "$BIN/code"
    log_link "Linked code -> $BIN/code"
else
    install_local_pkg "$PKGPATH"
fi

log_clean "Cleaning up downloaded package..."
rm "$PKGPATH"

log_done
