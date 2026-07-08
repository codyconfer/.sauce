#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

cleanup() {
    log_clean "Removing OpenCode..."
    remove_cmd opencode
    log_done "OpenCode removed."
    log_hint "Data under ~/.opencode (if any) was left in place."
}
dispatch_remove "$@"

log_download "Running the official OpenCode installer..."
fetch https://opencode.ai/install | bash

log_done
command -v opencode >/dev/null && opencode --version || true
log_hint "Restart your shell (PATH for opencode is set in your rc files)."
