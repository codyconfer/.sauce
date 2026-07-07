#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if ! ensure_node; then
    log_error "node/corepack not found; run update-nvm.sh (and install a node version) first."
    exit 1
fi

log_search "Enabling Corepack..."
corepack enable

log_download "Preparing the latest stable Yarn..."
corepack prepare yarn@stable --activate

log_done
command -v yarn >/dev/null && yarn --version || true
