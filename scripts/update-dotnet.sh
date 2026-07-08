#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

cleanup() {
    log_clean "Removing .NET..."
    remove_paths "$HOME/.dotnet"
    log_done ".NET removed."
}
dispatch_remove "$@"

SCRIPT=$(mktemp)
trap 'rm -f "$SCRIPT"' EXIT

log_download "Fetching the official dotnet-install script..."
fetch https://dot.net/v1/dotnet-install.sh > "$SCRIPT"

log_install "Installing .NET ($DOTNET_CHANNEL channel)..."
bash "$SCRIPT" --channel "$DOTNET_CHANNEL"

log_done
log_hint "Restart your shell (PATH for dotnet is set in your rc files)."
