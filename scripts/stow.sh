#! /bin/bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

case "${1:-stow}" in
    stow|restow)
        stow_all
        ;;
    unstow)
        for pkg in "${SAUCE_STOW_PACKAGES[@]}"; do
            unstow_pkg "$pkg"
        done
        log_done "Unstowed shell, prompt, and plugin configs."
        ;;
    *)
        log_error "usage: stow.sh [stow|restow|unstow]"
        exit 1
        ;;
esac
