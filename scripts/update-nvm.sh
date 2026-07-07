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
fetch "https://raw.githubusercontent.com/$REPO/$TAG/install.sh" | bash

profile_register nvm <<'EOF'
# nvm
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
if [ -d "$NVM_DIR" ]; then
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi
EOF
profile_register_fish nvm <<'EOF'
# nvm — nvm.sh is bash/zsh only; for fish install e.g. jorgebucaran/nvm.fish
set -gx NVM_DIR "$HOME/.nvm"
EOF

log_done
log_hint "Restart your shell to load nvm."
