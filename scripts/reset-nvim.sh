#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

STAMP="$(date +%Y%m%d%H%M%S)"

backup_and_remove() {
    local p="$1"
    if [ -e "$p" ] || [ -L "$p" ]; then
        log_clean "Backing up $p -> $p.$STAMP.bak"
        rm -rf "$p.$STAMP.bak"
        mv "$p" "$p.$STAMP.bak"
    fi
}

unstow_pkg nvim
backup_and_remove "$HOME/.config/nvim"
backup_and_remove "$HOME/.local/share/nvim"
backup_and_remove "$HOME/.local/state/nvim"
backup_and_remove "$HOME/.cache/nvim"

log_info "Cleared Neovim config + plugin state. Rebuilding..."
bash "$SCRIPT_DIR/build-nvim.sh"
