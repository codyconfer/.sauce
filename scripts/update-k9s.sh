#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

REPO="derailed/k9s"
DEST="$HOME/.local/bin/k9s"
TARBALL="k9s_Linux_amd64.tar.gz"
BASE="https://github.com/$REPO/releases/latest/download"

log_search "Fetching the latest k9s version..."
LATEST=$(fetch "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name')
if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
    log_error "Could not determine the latest k9s version."
    exit 1
fi
log_found "Latest version found: $LATEST"

INSTALLED=$(command -v k9s >/dev/null 2>&1 \
    && k9s version -s 2>/dev/null | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
version_gate "k9s" "$INSTALLED" "$LATEST" && exit 0

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log_download "Downloading $TARBALL..."
download "$BASE/$TARBALL" "$TMPDIR/$TARBALL"

EXPECTED_SHA=$(fetch "$BASE/checksums.sha256" | awk -v f="$TARBALL" '$2==f {print $1}')
if [ -n "$EXPECTED_SHA" ]; then
    verify_sha256 "$EXPECTED_SHA" "$TMPDIR/$TARBALL"
else
    log_warn "No checksum published for $TARBALL; skipping hash check."
fi

log_install "Installing to $DEST..."
tar -C "$TMPDIR" -xzf "$TMPDIR/$TARBALL" k9s
ensure_dir "$(dirname "$DEST")"
install -m 0755 "$TMPDIR/k9s" "$DEST"

log_done
"$DEST" version -s
