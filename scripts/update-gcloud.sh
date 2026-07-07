#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

SDK_ROOT="$HOME/google-cloud-sdk"
URL="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz"

if [ -d "$SDK_ROOT" ]; then
    log_install "Updating existing Google Cloud CLI components..."
    "$SDK_ROOT/bin/gcloud" components update --quiet
else
    TMPDIR=$(mktemp -d)
    trap 'rm -rf "$TMPDIR"' EXIT

    log_download "Downloading the latest Google Cloud CLI..."
    download "$URL" "$TMPDIR/google-cloud-cli.tar.gz"

    log_install "Extracting to $HOME..."
    tar -C "$HOME" -xzf "$TMPDIR/google-cloud-cli.tar.gz"

    log_install "Running the gcloud installer..."
    "$SDK_ROOT/install.sh" --quiet --path-update false --command-completion false
fi

log_done
"$SDK_ROOT/bin/gcloud" version
log_hint "Restart your shell (PATH for gcloud is set in your rc files)."
