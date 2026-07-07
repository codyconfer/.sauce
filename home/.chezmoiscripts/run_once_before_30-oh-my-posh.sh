#!/usr/bin/env bash

set -uo pipefail
source "$HOME/.sauce/scripts/lib/common.sh"

if command -v oh-my-posh >/dev/null 2>&1; then
    log_info "oh-my-posh already installed."
    exit 0
fi
log_download "Installing oh-my-posh..."
fetch https://ohmyposh.dev/install.sh | bash -s
