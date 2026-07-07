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

ensure_dir "$APPS"
PKG=$(basename "$URL")
PKGPATH="$APPS/$PKG"
log_download "Downloading $PKG..."
download "$URL" "$PKGPATH"

verify_sha256 "$SHA" "$PKGPATH"

log_install "Installing..."
if [ "$FAMILY" = "arch" ]; then
    DEST="$APPS/vscode"
    rm -rf "$DEST"
    ensure_dir "$DEST"
    tar -C "$DEST" --strip-components=1 -xzf "$PKGPATH"
    ensure_dir "$HOME/.local/bin"
    ln -sf "$DEST/bin/code" "$HOME/.local/bin/code"
    log_link "Linked code -> $HOME/.local/bin/code"
else
    install_local_pkg "$PKGPATH"
fi

log_clean "Cleaning up downloaded package..."
rm "$PKGPATH"

log_done
