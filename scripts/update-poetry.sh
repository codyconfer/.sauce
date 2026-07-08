#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

cleanup() {
    log_clean "Removing Poetry..."
    fetch https://install.python-poetry.org | python3 - --uninstall \
        || log_warn "Poetry uninstaller failed; remove ~/.local/share/pypoetry manually."
    log_done "Poetry removed."
}
dispatch_remove "$@"

log_download "Running the official Poetry installer..."
fetch https://install.python-poetry.org | python3 -

log_done
command -v poetry >/dev/null && poetry --version || true
