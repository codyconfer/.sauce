#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [ "$OS" = darwin ]; then macos_tool "${BASH_SOURCE[0]}" "$@"; exit $?; fi

case "$(detect_family)" in
    debian) PKG=docker-desktop-amd64.deb ;;
    fedora) PKG=docker-desktop-x86_64.rpm ;;
    arch)   PKG=docker-desktop-x86_64.pkg.tar.zst ;;
    *) log_error "unsupported distro (need apt, dnf, or pacman)."; exit 1 ;;
esac

cleanup() {
    log_clean "Removing Docker Desktop..."
    remove_pkgs docker-desktop
    log_done "Docker Desktop removed."
}
dispatch_remove "$@"

BASE=https://desktop.docker.com/linux/main/amd64
PKGPATH="$CACHE/$PKG"
HDRS=$(mktemp)
trap 'rm -f "$HDRS"' EXIT

ensure_dir "$CACHE"
log_download "Downloading $PKG..."
download_with_headers "$BASE/$PKG" "$PKGPATH" "$HDRS"

verify_md5_etag "$HDRS" "$PKGPATH"

log_install "Installing..."
install_local_pkg "$PKGPATH"

log_clean "Cleaning up downloaded package..."
rm "$PKGPATH"

log_done
