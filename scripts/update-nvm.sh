#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

REPO=nvm-sh/nvm

log_search "Fetching the latest nvm version..."
TAG=$(gh release view --repo "$REPO" --json tagName --jq '.tagName')
if [ -z "$TAG" ]; then
    log_error "Could not resolve the latest nvm tag."
    exit 1
fi
log_found "Latest version found: $TAG"

log_download "Running the nvm install script ($TAG)..."
fetch "https://raw.githubusercontent.com/$REPO/$TAG/install.sh" | PROFILE=/dev/null bash

log_done
log_hint "Restart your shell to load nvm (NVM_DIR is set in your rc files)."
