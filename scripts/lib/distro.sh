#! /bin/bash

detect_family() {
    if command -v apt-get >/dev/null 2>&1; then
        echo debian
    elif command -v dnf >/dev/null 2>&1; then
        echo fedora
    elif command -v pacman >/dev/null 2>&1; then
        echo arch
    else
        echo unknown
    fi
}

install_local_pkg() {
    local file="$1"
    case "$(detect_family)" in
        debian) sudo apt install -y "$file" ;;
        fedora) sudo dnf install -y "$file" ;;
        arch)   sudo pacman -U --noconfirm "$file" ;;
        *) echo "❌ Error: unsupported distro (need apt, dnf, or pacman)." >&2; return 1 ;;
    esac
}

pkg_refresh() {
    case "$(detect_family)" in
        debian) sudo apt update ;;
        fedora) sudo dnf check-update || true ;;
        arch)   sudo pacman -Sy ;;
        *) echo "❌ Error: unsupported distro (need apt, dnf, or pacman)." >&2; return 1 ;;
    esac
}

install_pkgs() {
    case "$(detect_family)" in
        debian) sudo apt install -y "$@" ;;
        fedora) sudo dnf install -y "$@" ;;
        arch)   sudo pacman -S --needed --noconfirm "$@" ;;
        *) echo "❌ Error: unsupported distro (need apt, dnf, or pacman)." >&2; return 1 ;;
    esac
}

ensure_flatpak() {
    if ! command -v flatpak >/dev/null 2>&1; then
        log_install "Installing flatpak..."
        install_pkgs flatpak || return 1
    fi
    flatpak remote-add --user --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
}

install_flatpak() {
    local app="$1"
    ensure_flatpak || return 1
    log_install "Installing/updating $app from Flathub..."
    flatpak install --user -y --or-update flathub "$app"
}
