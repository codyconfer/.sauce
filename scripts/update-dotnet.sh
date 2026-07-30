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

export DOTNET_ROOT="${DOTNET_ROOT:-$HOME/.dotnet}"
export PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools:$PATH"

if ! command -v dotnet >/dev/null 2>&1; then
    log_error "dotnet is not on PATH after install."
    exit 1
fi

if dotnet tool list --global 2>/dev/null | awk '{print tolower($1)}' | grep -qx powershell; then
    log_install "Updating PowerShell (dotnet global tool)..."
    dotnet tool update --global PowerShell || log_warn "PowerShell tool update failed."
else
    log_install "Installing PowerShell as a dotnet global tool..."
    dotnet tool install --global PowerShell || log_warn "PowerShell tool install failed."
fi

log_done
dotnet --version
command -v pwsh >/dev/null 2>&1 && pwsh --version || log_warn "pwsh not on PATH yet."
log_hint "Restart your shell (PATH for dotnet and its global tools is set in your rc files)."
