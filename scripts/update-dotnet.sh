#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

SCRIPT=$(mktemp)
trap 'rm -f "$SCRIPT"' EXIT

log_download "Fetching the official dotnet-install script..."
fetch https://dot.net/v1/dotnet-install.sh > "$SCRIPT"

log_install "Installing .NET ($DOTNET_CHANNEL channel)..."
bash "$SCRIPT" --channel "$DOTNET_CHANNEL"

profile_register dotnet <<'EOF'
# dotnet
export DOTNET_ROOT="$HOME/.dotnet"
if [ -d "$DOTNET_ROOT" ]; then
    export PATH="$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools"
fi
EOF
profile_register_fish dotnet <<'EOF'
# dotnet
set -gx DOTNET_ROOT "$HOME/.dotnet"
if test -d "$DOTNET_ROOT"
    fish_add_path -a "$DOTNET_ROOT" "$DOTNET_ROOT/tools"
end
EOF

log_done
log_hint "Restart your shell to update your PATH."
