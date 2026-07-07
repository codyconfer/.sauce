#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"

if [ -d "$PYENV_ROOT/.git" ]; then
    log_download "Updating existing pyenv install in $PYENV_ROOT..."
    git -C "$PYENV_ROOT" pull --ff-only
    for plugin in "$PYENV_ROOT"/plugins/*/; do
        [ -d "$plugin/.git" ] && git -C "$plugin" pull --ff-only || true
    done
else
    log_download "Running the official pyenv installer..."
    fetch https://pyenv.run | bash
fi

log_done
command -v pyenv >/dev/null && pyenv --version || true
log_hint "Restart your shell to load pyenv (PYENV_ROOT is set in your rc files)."
