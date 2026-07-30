#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [ "$OS" = darwin ]; then macos_tool "${BASH_SOURCE[0]}" "$@"; exit $?; fi

FAMILY=$(detect_family)
API="https://api.github.com/repos/bitwarden/clients/releases?per_page=100"
FLATPAK_ID="com.bitwarden.desktop"

cleanup() {
    log_clean "Removing Bitwarden..."
    remove_pkgs bitwarden || log_warn "package removal failed (Bitwarden may not be installed)."
    log_done "Bitwarden removed."
}
dispatch_remove "$@"

if command -v flatpak >/dev/null 2>&1 && flatpak info "$FLATPAK_ID" >/dev/null 2>&1; then
    log_warn "The sandboxed Flathub build ($FLATPAK_ID) is still installed."
    log_hint "Remove it so the native package owns the launcher: flatpak uninstall --user -y $FLATPAK_ID"
fi

if [ "$FAMILY" = arch ]; then
    log_install "Installing Bitwarden from the Arch repos..."
    install_pkgs bitwarden
    log_done
    log_hint "pacman keeps Bitwarden updated — 'update' (or 'pacman -Syu') upgrades it."
    exit 0
fi

case "$FAMILY" in
    debian) PKG_SUFFIX="-amd64.deb" ;;
    fedora) PKG_SUFFIX="-x86_64.rpm" ;;
    *) log_error "unsupported distro (need apt, dnf, or pacman)."; exit 1 ;;
esac

if [ "$ARCH" != amd64 ]; then
    log_error "Bitwarden ships no native $FAMILY package for $ARCH (x86_64 only)."
    exit 1
fi

log_search "Fetching the latest Bitwarden Desktop version..."
META=$(fetch "$API")
REL=$(echo "$META" | jq -c '[.[]
    | select(.draft == false and .prerelease == false)
    | select(.tag_name | startswith("desktop-v"))] | .[0] // empty')
VERSION=$(echo "$REL" | jq -r '.tag_name // empty' | sed 's/^desktop-v//')
URL=$(echo "$REL" | jq -r --arg s "$PKG_SUFFIX" \
    '.assets[]? | select(.name | endswith($s)) | .browser_download_url' | head -n1)
YML_URL=$(echo "$REL" | jq -r '.assets[]? | select(.name == "latest-linux.yml") | .browser_download_url' | head -n1)
if [ -z "$VERSION" ] || [ -z "$URL" ]; then
    log_error "Could not resolve the latest Bitwarden Desktop package."
    exit 1
fi
log_found "Latest version found: $VERSION"

case "$FAMILY" in
    debian) INSTALLED=$(dpkg-query -W -f='${Version}' bitwarden 2>/dev/null || true) ;;
    fedora) INSTALLED=$(rpm -q --qf '%{VERSION}' bitwarden 2>/dev/null || true) ;;
esac
version_gate "Bitwarden" "$INSTALLED" "$VERSION" && exit 0

ensure_dir "$CACHE"
PKG=$(basename "$URL")
PKGPATH="$CACHE/$PKG"
log_download "Downloading $PKG..."
download "$URL" "$PKGPATH"

SHA=""
if [ -n "$YML_URL" ]; then
    SHA=$(fetch "$YML_URL" 2>/dev/null | grep -A1 -F "url: $PKG" | grep -m1 'sha512:' | awk '{print $2}' || true)
fi
verify_sha512_base64 "$SHA" "$PKGPATH"

log_install "Installing $PKG..."
install_local_pkg "$PKGPATH"

log_clean "Cleaning up downloaded package..."
rm -f "$PKGPATH"

log_done
log_hint "Launch Bitwarden from your app menu or run 'bitwarden'."
