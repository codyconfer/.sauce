#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [ "$OS" = darwin ]; then
    log_info "k3s is Linux-only — skipping on macOS."
    exit 0
fi

cleanup() {
    log_clean "Removing k3s..."
    if [ -x /usr/local/bin/k3s-uninstall.sh ]; then
        sudo /usr/local/bin/k3s-uninstall.sh || log_warn "k3s-uninstall.sh failed."
    else
        log_info "k3s-uninstall.sh not found; nothing to remove."
    fi
    log_done "k3s removed."
}
dispatch_remove "$@"

log_download "Running the official k3s installer (get.k3s.io)..."
fetch https://get.k3s.io | sh -

log_done
command -v k3s >/dev/null && k3s --version | head -n1 || true
