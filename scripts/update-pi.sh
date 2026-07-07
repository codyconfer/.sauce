#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if ! ensure_node; then
    log_error "npm not found; the pi installer needs node. Run update-nvm.sh (and install a node version) first."
    exit 1
fi

log_download "Running the official pi installer..."
fetch https://pi.dev/install.sh | sh

log_done
command -v pi >/dev/null && pi --version || true
