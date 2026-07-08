#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [ "$OS" = darwin ]; then macos_tool "${BASH_SOURCE[0]}" "$@"; exit $?; fi

cleanup() {
    log_clean "Removing Ollama..."
    if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files ollama.service >/dev/null 2>&1; then
        sudo systemctl stop ollama 2>/dev/null || true
        sudo systemctl disable ollama 2>/dev/null || true
    fi
    remove_sudo_paths /usr/local/bin/ollama /usr/share/ollama /etc/systemd/system/ollama.service
    log_done "Ollama removed."
    log_hint "Pulled models (~/.ollama) and the 'ollama' service user were left in place."
}
dispatch_remove "$@"

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
