#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if ! command -v sway >/dev/null 2>&1; then
    log_warn "sway not installed; run install-sway.sh first. Linking configs anyway."
fi

for cfg in sway waybar wofi mako foot; do
    stow_pkg "$cfg"
done

log_done "Sway config linked."
log_hint "Reload a running session with '\$mod+Shift+c', or log out and pick 'Sway'."
