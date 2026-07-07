#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_download "Running the official OpenCode installer..."
fetch https://opencode.ai/install | bash

log_done
command -v opencode >/dev/null && opencode --version || true
log_hint "Restart your shell (PATH for opencode is set in your rc files)."
