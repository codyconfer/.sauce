#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

cleanup() {
    log_clean "Removing Zed..."
    remove_cmd zed
    remove_paths "$HOME/.local/share/zed"
    log_done "Zed removed."
    log_hint "Config under ~/.config/zed was left in place."
}
dispatch_remove "$@"

log_download "Running the official Zed installer..."
fetch https://zed.dev/install.sh | sh

log_done
