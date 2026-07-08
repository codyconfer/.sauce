#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

cleanup() {
    log_clean "Removing Azure CLI..."
    if command -v pipx >/dev/null 2>&1; then
        pipx uninstall azure-cli || log_warn "pipx uninstall failed (azure-cli may not be installed)."
    else
        log_warn "pipx not found; nothing to uninstall."
    fi
    log_done "Azure CLI removed."
}
dispatch_remove "$@"

if ! command -v pipx >/dev/null 2>&1; then
    log_error "pipx not found; it is installed with the base packages (chezmoi apply). Install pipx first."
    exit 1
fi

if pipx list --short 2>/dev/null | grep -q '^azure-cli\b'; then
    log_install "Updating Azure CLI via pipx..."
    pipx upgrade azure-cli
else
    log_install "Installing Azure CLI via pipx..."
    pipx install azure-cli
fi

log_done
az version
