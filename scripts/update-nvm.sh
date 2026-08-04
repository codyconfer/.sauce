#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

REPO=nvm-sh/nvm

cleanup() {
    log_clean "Removing nvm..."
    remove_paths "${NVM_DIR:-$HOME/.nvm}"
    log_done "nvm removed."
    log_hint "Your rc files still source nvm (chezmoi-managed); the block is a harmless no-op once nvm is gone."
}
dispatch_remove "$@"

log_search "Fetching the latest nvm version..."
TAG=$(fetch "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name')
if [ -z "$TAG" ] || [ "$TAG" = "null" ]; then
    log_error "Could not resolve the latest nvm tag."
    exit 1
fi
log_found "Latest version found: $TAG"

log_download "Running the nvm install script ($TAG)..."
fetch "https://raw.githubusercontent.com/$REPO/$TAG/install.sh" | PROFILE=/dev/null bash

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    log_error "nvm.sh not found in $NVM_DIR after install."
    exit 1
fi

log_install "Installing the latest Node LTS and making it the default..."
set +eu
\. "$NVM_DIR/nvm.sh"
nvm install --lts
RC=$?
if [ "$RC" -eq 0 ]; then
    nvm alias default 'lts/*' >/dev/null
    RC=$?
fi
set -eu
if [ "$RC" -ne 0 ]; then
    log_error "Could not install the latest Node LTS."
    exit 1
fi

log_done "node $(node --version) / npm $(npm --version) is the nvm default."
log_hint "Restart your shell to load nvm (NVM_DIR is set in your rc files)."
