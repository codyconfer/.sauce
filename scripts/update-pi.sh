#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_download "Running the official pi installer..."
fetch https://pi.dev/install.sh | sh

log_done
command -v pi >/dev/null && pi --version || true
