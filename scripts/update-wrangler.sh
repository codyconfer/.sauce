#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

cleanup() {
    log_clean "Removing wrangler..."
    if ensure_node; then
        npm uninstall -g wrangler || log_warn "npm uninstall failed (wrangler may not be installed)."
    else
        log_warn "npm not found; nothing to uninstall."
    fi
    log_done "wrangler removed."
}
dispatch_remove "$@"

if ! ensure_node; then
    log_error "npm not found; run update-nvm.sh (and install a node version) first."
    exit 1
fi

log_install "Installing/updating wrangler via npm..."
npm install -g wrangler

log_done
command -v wrangler >/dev/null && wrangler --version || true
log_hint "Restart your shell if wrangler isn't on your PATH yet."
