#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

cleanup() {
    log_clean "Removing Claude Code..."
    remove_cmd claude
    log_done "Claude Code removed."
    log_hint "Config under ~/.claude was left in place."
}
dispatch_remove "$@"

log_download "Running the official Claude Code installer..."
fetch https://claude.ai/install.sh | bash

log_done
command -v claude >/dev/null && claude --version || true
log_hint "Claude Code installs to ~/.local/bin (already on your PATH); 'claude update' also self-updates."
