#! /bin/bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/runner.sh"

run_step "install-base.sh" bash "$SCRIPT_DIR/install-base.sh"
run_update_scripts "$SCRIPT_DIR"
print_summary
