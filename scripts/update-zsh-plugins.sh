#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PLUGINS=(
    "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions"
    "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting"
)

ensure_dir "$ZSH_PLUGINS"
for entry in "${PLUGINS[@]}"; do
    name=${entry%%|*}; url=${entry#*|}
    dest="$ZSH_PLUGINS/$name"
    if [ -d "$dest/.git" ]; then
        echo "🔄 Updating $name..."
        git -C "$dest" pull --ff-only
    else
        log_download "Cloning $name..."
        git clone --depth 1 "$url" "$dest"
    fi
done

log_done
log_hint "The loader (~/.zsh/plugins.zsh) is stowed from the repo; restart your shell to load the plugins."
