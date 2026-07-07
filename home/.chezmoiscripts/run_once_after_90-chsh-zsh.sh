#!/usr/bin/env bash

set -uo pipefail

zsh_path="$(command -v zsh || true)"
[ -z "$zsh_path" ] && { echo "⚠️  zsh not found; skipping chsh."; exit 0; }
if [ "${SHELL:-}" = "$zsh_path" ]; then
    echo "ℹ️  Login shell already zsh."
    exit 0
fi
echo "🔧 Setting zsh as your login shell..."
chsh -s "$zsh_path" || echo "⚠️  chsh failed; set zsh as your login shell manually."
