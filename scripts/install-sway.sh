#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_install "Installing sway and companions..."
install_pkgs \
    sway swaybg swayidle swaylock \
    waybar wofi foot \
    grim slurp wl-clipboard \
    brightnessctl \
    xdg-desktop-portal-wlr

case "$(detect_family)" in
    debian) install_pkgs mako-notifier ;;
    *)      install_pkgs mako ;;
esac

log_done
log_hint "Log out and pick 'Sway' at your display manager, or run 'sway' from a TTY."
