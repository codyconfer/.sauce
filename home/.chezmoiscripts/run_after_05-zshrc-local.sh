#!/usr/bin/env bash
set -euo pipefail
target="$HOME/.zshrc.local"
[ -e "$target" ] && exit 0
cat >"$target" <<'EOF'
# ~/.zshrc.local — your personal, machine-local zsh tweaks.
# Not tracked by chezmoi: created once if missing, then never touched.
# Sourced at the end of ~/.zshrc, after any role fragments.
EOF
