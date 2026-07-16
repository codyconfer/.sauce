#!/usr/bin/env bash
set -euo pipefail

SAUCE_DIR="${SAUCE_DIR:-$HOME/.sauce}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

log() { echo "▶️  $*"; }

if command -v chezmoi >/dev/null 2>&1; then
    CHEZMOI="$(command -v chezmoi)"
else
    log "Installing chezmoi to $BIN_DIR..."
    mkdir -p "$BIN_DIR"
    sh -c "$(curl -fsSL https://get.chezmoi.io)" -- -b "$BIN_DIR"
    CHEZMOI="$BIN_DIR/chezmoi"
fi

if [ ! -d "$SAUCE_DIR/.git" ]; then
    log "Cloning .sauce to $SAUCE_DIR..."
    git clone "https://github.com/codyconfer/.sauce.git" "$SAUCE_DIR"
fi

if [ -f "$SAUCE_DIR/.env" ]; then
    log "Sourcing $SAUCE_DIR/.env for chezmoi config defaults..."
    set -a
    . "$SAUCE_DIR/.env"
    set +a
fi

log "Running chezmoi init --apply..."
"$CHEZMOI" init --source="$SAUCE_DIR" --apply

echo "✅ Done. Start a new shell (zsh) to pick everything up."
