#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DEST="$HOME/.local/bin/kubectl"

cleanup() {
    log_clean "Removing kubectl..."
    remove_paths "$DEST"
    log_done "kubectl removed."
}
dispatch_remove "$@"

log_search "Fetching the latest stable kubectl version..."
LATEST=$(fetch "https://dl.k8s.io/release/stable.txt" | tr -d '[:space:]')
if [ -z "$LATEST" ]; then
    log_error "Could not determine the latest kubectl version."
    exit 1
fi
log_found "Latest version found: $LATEST"

INSTALLED=$(command -v kubectl >/dev/null 2>&1 \
    && kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion // empty' || true)
version_gate "kubectl" "$INSTALLED" "$LATEST" && exit 0

BASE="https://dl.k8s.io/release/$LATEST/bin/linux/amd64"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log_download "Downloading kubectl $LATEST..."
download "$BASE/kubectl" "$TMPDIR/kubectl"

EXPECTED_SHA=$(fetch "$BASE/kubectl.sha256" | tr -d '[:space:]')
if [ -n "$EXPECTED_SHA" ]; then
    verify_sha256 "$EXPECTED_SHA" "$TMPDIR/kubectl"
else
    log_warn "No checksum published for kubectl; skipping hash check."
fi

log_install "Installing to $DEST..."
ensure_dir "$(dirname "$DEST")"
install -m 0755 "$TMPDIR/kubectl" "$DEST"

log_done
"$DEST" version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' || "$DEST" version --client
