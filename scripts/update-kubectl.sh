#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

ARCH=amd64
DEST="$HOME/.local/bin"
BIN="$DEST/kubectl"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log_search "Fetching the latest kubectl version..."
VERSION=$(fetch https://dl.k8s.io/release/stable.txt)
if [ -z "$VERSION" ]; then
    log_error "Could not determine the latest kubectl version."
    exit 1
fi
log_found "Latest version found: $VERSION"

INSTALLED=$(command -v kubectl >/dev/null 2>&1 && kubectl version --client 2>/dev/null | grep -om1 'v[0-9][^ ]*' || true)
version_gate "kubectl" "$INSTALLED" "$VERSION" && exit 0

BASE="https://dl.k8s.io/release/$VERSION/bin/linux/$ARCH"
log_download "Downloading kubectl $VERSION..."
download "$BASE/kubectl" "$TMPDIR/kubectl"

SHA=$(fetch "$BASE/kubectl.sha256")
verify_sha256 "$SHA" "$TMPDIR/kubectl"

log_install "Installing to $DEST..."
ensure_dir "$DEST"
install -m755 "$TMPDIR/kubectl" "$BIN"

log_done
"$BIN" version --client || true
