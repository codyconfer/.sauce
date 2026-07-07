#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_download "Running the official pyenv installer..."
fetch https://pyenv.run | bash

profile_register pyenv <<'EOF'
# pyenv
export PYENV_ROOT="$HOME/.pyenv"
if [ -d "$PYENV_ROOT" ]; then
    command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
fi
EOF
profile_register_fish pyenv <<'EOF'
# pyenv
set -gx PYENV_ROOT "$HOME/.pyenv"
if test -d "$PYENV_ROOT"
    fish_add_path "$PYENV_ROOT/bin"
    pyenv init - fish | source
end
EOF

log_done
command -v pyenv >/dev/null && pyenv --version || true
log_hint "Restart your shell to load pyenv."
