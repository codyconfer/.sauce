#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

cleanup() {
    log_clean "Removing pi..."
    remove_cmd pi
    log_done "pi removed."
    log_hint "Data under ~/.pi (if any) was left in place."
}
dispatch_remove "$@"

if ! ensure_node; then
    log_error "npm not found; the pi installer needs node. Run update-nvm.sh (and install a node version) first."
    exit 1
fi

log_download "Running the official pi installer (headless)..."
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
fetch https://pi.dev/install.sh > "$tmp"
if command -v setsid >/dev/null 2>&1; then
    setsid --wait sh "$tmp" </dev/null
else
    log_warn "setsid not found; running installer normally (it may prompt)."
    sh "$tmp" </dev/null
fi

log_done
command -v pi >/dev/null && pi --version || true
