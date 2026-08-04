#!/usr/bin/env bash
set -euo pipefail
target="$HOME/.config/fish/user.fish"
[ -e "$target" ] && exit 0
mkdir -p "$(dirname "$target")"
cat >"$target" <<'EOF'
# ~/.config/fish/user.fish — your personal fish tweaks.
# Not tracked by chezmoi: created once if missing, then never touched.
# Sourced at the end of config.fish, after any role fragments.
EOF
