#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

cleanup() {
    log_clean "Removing Yarn..."
    if ensure_node && command -v corepack >/dev/null 2>&1; then
        corepack disable yarn 2>/dev/null || corepack disable 2>/dev/null || true
    fi
    log_done "Yarn disabled."
    log_hint "Yarn ships via Corepack (bundled with Node); it's disabled, not deleted. Removing Node/nvm removes it entirely."
}
dispatch_remove "$@"

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
