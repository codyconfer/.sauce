#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PKG=lm-studio.AppImage
URL=https://lmstudio.ai/download/latest/linux/x64
PKGPATH=$APPS/$PKG
HDRS=$(mktemp)
trap 'rm -f "$HDRS"' EXIT

ensure_dir "$APPS"
log_download "Downloading $PKG..."
download_with_headers "$URL" "$PKGPATH" "$HDRS"

verify_md5_etag "$HDRS" "$PKGPATH"

log_install "Making AppImage executable..."
chmod +x "$PKGPATH"

profile_register lmstudio <<'EOF'
# lm studio cli
[ -d "$HOME/.lmstudio/bin" ] && export PATH="$PATH:$HOME/.lmstudio/bin"
EOF
profile_register_fish lmstudio <<'EOF'
# lm studio cli
test -d "$HOME/.lmstudio/bin"; and fish_add_path -a "$HOME/.lmstudio/bin"
EOF

log_done
log_hint "Restart your shell to update your PATH."
