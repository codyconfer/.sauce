#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_download "Running the official OpenCode installer..."
fetch https://opencode.ai/install | bash

profile_register opencode <<'EOF'
# opencode
[ -d "$HOME/.opencode/bin" ] && export PATH="$HOME/.opencode/bin:$PATH"
EOF
profile_register_fish opencode <<'EOF'
# opencode
test -d "$HOME/.opencode/bin"; and fish_add_path "$HOME/.opencode/bin"
EOF

log_done
command -v opencode >/dev/null && opencode --version || true
log_hint "Restart your shell to update your PATH."
