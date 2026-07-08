#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

cleanup() {
    log_clean "Removing loglit..."
    local gobin
    if command -v go >/dev/null 2>&1; then
        gobin="$(go env GOBIN)"; [ -n "$gobin" ] || gobin="$(go env GOPATH)/bin"
    else
        gobin="${GOBIN:-${GOPATH:-$HOME/go}/bin}"
    fi
    remove_paths "$gobin/loglit"
    remove_stamp loglit
    log_done "loglit removed."
}
dispatch_remove "$@"

if ! command -v go >/dev/null 2>&1; then
    log_error "Go is required to install loglit. Run update-go first."
    exit 1
fi

log_search "Fetching the latest loglit commit..."
LATEST=$(fetch "https://api.github.com/repos/madmaxieee/loglit/commits?per_page=1" | jq -r '.[0].sha')
if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
    log_error "Could not determine the latest loglit commit."
    exit 1
fi
log_found "Latest commit found: ${LATEST:0:12}"

INSTALLED=$(read_stamp loglit)
version_gate "loglit" "$INSTALLED" "$LATEST" && exit 0

log_download "Installing loglit via go install..."
go install github.com/madmaxieee/loglit@latest

write_stamp loglit "$LATEST"

log_done
GOBIN_DIR="$(go env GOBIN)"; [ -n "$GOBIN_DIR" ] || GOBIN_DIR="$(go env GOPATH)/bin"
log_hint "Ensure $GOBIN_DIR is on your PATH."
