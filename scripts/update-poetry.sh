#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_download "Running the official Poetry installer..."
fetch https://install.python-poetry.org | python3 -

log_done
command -v poetry >/dev/null && poetry --version || true
