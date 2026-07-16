#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

cleanup() {
    log_clean "Removing the Rust toolchain (rustup self uninstall)..."
    if command -v rustup >/dev/null 2>&1; then
        rustup self uninstall -y || log_warn "rustup self uninstall failed; remove ~/.rustup and ~/.cargo manually."
    else
        log_info "rustup not installed; nothing to remove."
    fi
    log_done "Rust toolchain removed."
}
dispatch_remove "$@"

if command -v rustup >/dev/null 2>&1; then
    log_download "Updating the existing Rust toolchain..."
    rustup self update || log_warn "rustup self update failed (package-managed rustup?)."
    rustup update
else
    log_download "Installing rustup (official installer)..."
    fetch https://sh.rustup.rs | sh -s -- -y --no-modify-path
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
fi

command -v rustup >/dev/null 2>&1 && rustup default stable || true

log_done
command -v rustc >/dev/null && rustc --version || true
