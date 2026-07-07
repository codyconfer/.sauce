#! /bin/bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

FAMILY=$(detect_family)
if [ "$FAMILY" = unknown ]; then
    log_error "unsupported distro (need apt, dnf, or pacman)."
    exit 1
fi

pkg_refresh || true

essential=(git curl wget unzip jq figlet zsh neovim gcc make stow)
extras=(gh rustup pipx htop btop iftop iotop s-tui wavemon)
case "$FAMILY" in
    debian) essential+=(xz-utils build-essential) ;;
    fedora) essential+=(xz) ;;
    arch)   essential+=(xz base-devel); extras=("${extras[@]/pipx/python-pipx}") ;;
esac

log_install "Installing essential packages..."
install_pkgs "${essential[@]}" || { log_error "Failed to install essential packages."; exit 1; }

log_install "Installing extra packages (best-effort)..."
for p in "${extras[@]}"; do
    install_pkgs "$p" || log_warn "skipped (unavailable): $p"
done

command -v rustup >/dev/null 2>&1 && rustup default stable || true
command -v pipx   >/dev/null 2>&1 && pipx ensurepath || true

log_done
