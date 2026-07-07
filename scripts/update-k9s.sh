#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

REPO=derailed/k9s
TARBALL=k9s_Linux_amd64.tar.gz
DEST="$HOME/.local/bin"
BIN="$DEST/k9s"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log_search "Fetching the latest k9s version..."
TAG=$(gh release view --repo "$REPO" --json tagName --jq '.tagName')
if [ -z "$TAG" ]; then
    log_error "Could not resolve the latest k9s tag."
    exit 1
fi
log_found "Latest version found: $TAG"

INSTALLED=$([ -x "$BIN" ] && "$BIN" version -s 2>/dev/null | grep -om1 'v[0-9][^ ]*' || true)
version_gate "k9s" "$INSTALLED" "$TAG" && exit 0

BASE="https://github.com/$REPO/releases/download/$TAG"
log_download "Downloading k9s $TAG..."
download "$BASE/$TARBALL" "$TMPDIR/$TARBALL"

SHA=$(fetch "$BASE/checksums.sha256" | awk -v f="$TARBALL" '$2==f {print $1}')
if [ -z "$SHA" ]; then
    log_error "Could not find a checksum for $TARBALL."
    exit 1
fi
verify_sha256 "$SHA" "$TMPDIR/$TARBALL"

log_install "Installing to $DEST..."
tar -C "$TMPDIR" -xzf "$TMPDIR/$TARBALL" k9s
ensure_dir "$DEST"
install -m755 "$TMPDIR/k9s" "$BIN"

log_done
"$BIN" version
