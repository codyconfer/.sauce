#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

REPO=neovim/neovim
ASSET=nvim-linux-x86_64.tar.gz
DEST="$APPS/nvim"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log_search "Fetching the latest Neovim (stable) version..."
VERSION=$(gh release view --repo "$REPO" stable --json name --jq '.name' 2>/dev/null || true)
log_found "Latest stable: ${VERSION:-unknown}"

LATEST=$(echo "$VERSION" | grep -om1 'v[0-9][^ ]*' || true)
INSTALLED=$([ -x "$DEST/bin/nvim" ] && "$DEST/bin/nvim" --version 2>/dev/null | head -1 | grep -om1 'v[0-9][^ ]*' || true)
version_gate "Neovim" "$INSTALLED" "$LATEST" && exit 0

log_download "Downloading $ASSET..."
gh release download --repo "$REPO" stable \
    --pattern "$ASSET" --pattern "$ASSET.sha256sum" \
    --dir "$TMPDIR" --clobber

log_verify "Verifying checksum..."
( cd "$TMPDIR" && sha256sum -c "$ASSET.sha256sum" )

log_install "Installing to $DEST..."
ensure_dir "$APPS"
rm -rf "$DEST"
ensure_dir "$DEST"
tar -C "$DEST" --strip-components=1 -xzf "$TMPDIR/$ASSET"

profile_register neovim <<'EOF'
# Neovim (latest, installed by update-neovim)
[ -d "$HOME/.apps/nvim/bin" ] && export PATH="$HOME/.apps/nvim/bin:$PATH"
EOF
profile_register_fish neovim <<'EOF'
# Neovim (latest, installed by update-neovim)
test -d "$HOME/.apps/nvim/bin"; and fish_add_path -p "$HOME/.apps/nvim/bin"
EOF

log_done
"$DEST/bin/nvim" --version | head -1 || true
log_hint "Restart your shell (or 'source ~/.zshrc') so the new nvim takes precedence."
