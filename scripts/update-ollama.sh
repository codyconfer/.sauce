#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_search "Fetching the latest Ollama version..."
LATEST=$(fetch "https://api.github.com/repos/ollama/ollama/releases/latest" | jq -r '.tag_name')
if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
    log_error "Could not determine the latest Ollama version."
    exit 1
fi
log_found "Latest version found: $LATEST"

INSTALLED=$(command -v ollama >/dev/null 2>&1 && ollama --version 2>/dev/null | awk '{print $NF}' || true)
version_gate "Ollama" "$INSTALLED" "$LATEST" && exit 0

log_download "Running the official Ollama installer..."
fetch https://ollama.com/install.sh | sh

log_done
command -v ollama >/dev/null && ollama --version || true
