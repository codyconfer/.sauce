#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

cleanup() {
    log_clean "Removing gcx..."
    remove_cmd gcx
    log_done "gcx removed."
}
dispatch_remove "$@"

log_download "Running the official gcx (Grafana Cloud CLI) installer..."
fetch https://raw.githubusercontent.com/grafana/gcx/main/scripts/install.sh | sh

log_done
command -v gcx >/dev/null && gcx --version || true
log_hint "Restart your shell if gcx isn't on your PATH yet."
