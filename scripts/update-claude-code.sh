#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_download "Running the official Claude Code installer..."
fetch https://claude.ai/install.sh | bash

log_done
command -v claude >/dev/null && claude --version || true
log_hint "Claude Code installs to ~/.local/bin (already on your PATH); 'claude update' also self-updates."
