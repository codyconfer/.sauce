#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

cleanup() {
    log_clean "Removing Go..."
    remove_sudo_paths /usr/local/go
    log_done "Go removed."
    log_hint "Your GOPATH (~/go) with installed tools was left in place."
}
dispatch_remove "$@"

log_search "Fetching the latest Go version..."
RELEASE_JSON=$(fetch "https://go.dev/dl/?mode=json")

LATEST_VERSION=$(echo "$RELEASE_JSON" | jq -r '.[0].version')
if [ -z "$LATEST_VERSION" ] || [ "$LATEST_VERSION" = "null" ]; then
    log_error "Could not determine the latest Go version."
    exit 1
fi
log_found "Latest version found: $LATEST_VERSION"

INSTALLED=$(command -v go >/dev/null 2>&1 && go version | awk '{print $3}' || true)
version_gate "Go" "$INSTALLED" "$LATEST_VERSION" && exit 0

TARBALL="${LATEST_VERSION}.${GO_ARCH}.tar.gz"
DOWNLOAD_URL="https://go.dev/dl/${TARBALL}"

EXPECTED_SHA=$(echo "$RELEASE_JSON" \
    | jq -r --arg f "$TARBALL" '.[0].files[] | select(.filename == $f) | .sha256')
if [ -z "$EXPECTED_SHA" ] || [ "$EXPECTED_SHA" = "null" ]; then
    log_error "Could not find a checksum for $TARBALL."
    exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log_download "Downloading $TARBALL..."
download "$DOWNLOAD_URL" "$TMPDIR/$TARBALL"

verify_sha256 "$EXPECTED_SHA" "$TMPDIR/$TARBALL"

echo "🧹 Removing any existing Go installation..."
sudo rm -rf /usr/local/go

log_install "Extracting to /usr/local..."
sudo tar -C /usr/local -xzf "$TMPDIR/$TARBALL"

export PATH=$PATH:/usr/local/go/bin

log_done
go version
log_hint "Restart your shell to update your PATH."
