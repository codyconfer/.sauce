#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

case "$(detect_family)" in
    debian)
        log_install "Enabling i386 multiarch..."
        sudo dpkg --add-architecture i386
        sudo apt update
        PKG=steam_latest.deb
        PKGPATH="$APPS/$PKG"
        ensure_dir "$APPS"
        log_download "Downloading the Steam installer..."
        download "https://repo.steampowered.com/steam/archive/stable/steam_latest.deb" "$PKGPATH"
        log_install "Installing (apt resolves dependencies)..."
        install_local_pkg "$PKGPATH"
        log_clean "Cleaning up downloaded package..."
        rm -f "$PKGPATH"
        ;;
    fedora)
        log_install "Enabling RPM Fusion (free + nonfree)..."
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
        install_pkgs steam
        ;;
    arch)
        if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
            log_install "Enabling the multilib repo in /etc/pacman.conf..."
            sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
            sudo pacman -Sy
        fi
        install_pkgs steam
        ;;
    *)
        log_error "unsupported distro (need apt, dnf, or pacman)."
        exit 1
        ;;
esac

log_done
log_hint "Launch Steam from your app menu; it will finish updating on first run."
