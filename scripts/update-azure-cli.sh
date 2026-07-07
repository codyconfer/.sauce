#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if ! command -v pipx >/dev/null 2>&1; then
    log_error "pipx not found; it is installed by setup.sh's base packages. Install pipx first."
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
