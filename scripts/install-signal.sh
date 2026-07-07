#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

install_flatpak org.signal.Signal

log_done
log_hint "Launch Signal from your app menu, or run: flatpak run org.signal.Signal"
