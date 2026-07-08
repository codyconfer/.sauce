#!/usr/bin/env bash
# Bootstrap a fresh machine with chezmoi + this repo.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/codyconfer/.sauce/main/bootstrap.sh)
#
# or, if you've already cloned the repo:
#
#   bash ~/.sauce/bootstrap.sh
#
# Installs chezmoi (to ~/.local/bin), clones this repo to ~/.sauce (if missing),
# and runs `chezmoi init --apply` — which provisions packages, dotfiles, tools,
# and shell. Safe to re-run; every step is idempotent.
set -euo pipefail

SAUCE_DIR="${SAUCE_DIR:-$HOME/.sauce}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

log() { echo "▶️  $*"; }

# 1. chezmoi
if command -v chezmoi >/dev/null 2>&1; then
    CHEZMOI="$(command -v chezmoi)"
else
    log "Installing chezmoi to $BIN_DIR..."
    mkdir -p "$BIN_DIR"
    sh -c "$(curl -fsSL https://get.chezmoi.io)" -- -b "$BIN_DIR"
    CHEZMOI="$BIN_DIR/chezmoi"
fi

# 2. repo (chezmoi sourceDir). If we're already running from inside a clone, reuse it.
if [ ! -d "$SAUCE_DIR/.git" ]; then
    log "Cloning .sauce to $SAUCE_DIR..."
    git clone "https://github.com/codyconfer/.sauce.git" "$SAUCE_DIR"
fi

# 3. init + apply. --source points chezmoi at the repo; .chezmoiroot sends it into home/.
log "Running chezmoi init --apply..."
"$CHEZMOI" init --source="$SAUCE_DIR" --apply

echo "✅ Done. Start a new shell (zsh) to pick everything up."
