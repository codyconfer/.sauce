#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if ! command -v npm >/dev/null 2>&1; then
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    unset npm_config_prefix 2>/dev/null || true
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || true
fi

if ! command -v npm >/dev/null 2>&1; then
    log_error "npm not found; run update-nvm.sh (and install a node version) first."
    exit 1
fi

log_install "Installing/updating wrangler via npm..."
npm install -g wrangler

log_done
command -v wrangler >/dev/null && wrangler --version || true
log_hint "Restart your shell if wrangler isn't on your PATH yet."
