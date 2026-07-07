#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

install_flatpak app.zen_browser.zen

log_done
log_hint "Launch Zen Browser from your app menu, or run: flatpak run app.zen_browser.zen"
