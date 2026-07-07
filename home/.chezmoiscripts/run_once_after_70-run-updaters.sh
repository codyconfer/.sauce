#!/usr/bin/env bash

set -uo pipefail

if [ ! -x "$HOME/.sauce/scripts/update-all.sh" ] && [ ! -f "$HOME/.sauce/scripts/update-all.sh" ]; then
    echo "⚠️  scripts/update-all.sh not found; skipping updaters."
    exit 0
fi

echo "▶️  Running self-updating tool installers (scripts/update-all.sh)..."
bash "$HOME/.sauce/scripts/update-all.sh" \
    || echo "⚠️  Some updaters failed; re-run individually (e.g. 'update-go') or 'update-all'."
