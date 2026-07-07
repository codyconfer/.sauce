#! /bin/bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/runner.sh"

# Runs every scripts/update-*.sh (self-updating tools). Base packages and one-time
# app installs are handled by chezmoi (`chezmoi apply`), not here.
run_update_scripts "$SCRIPT_DIR"
print_summary
