#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

install_flatpak com.bitwarden.desktop

log_done
log_hint "Launch Bitwarden from your app menu, or run: flatpak run com.bitwarden.desktop"
