#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if ! ensure_node; then
    log_error "npm not found; run update-nvm.sh (and install a node version) first."
    exit 1
fi

log_install "Installing/updating the OpenAI Codex CLI via npm..."
npm install -g @openai/codex

log_done
command -v codex >/dev/null && codex --version || true
log_hint "Restart your shell if codex isn't on your PATH yet."
