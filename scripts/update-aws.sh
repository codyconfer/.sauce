#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

cleanup() {
    log_clean "Removing AWS CLI v2..."
    remove_sudo_paths /usr/local/aws-cli /usr/local/bin/aws /usr/local/bin/aws_completer
    log_done "AWS CLI removed."
}
dispatch_remove "$@"

URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log_download "Downloading the latest AWS CLI v2..."
download "$URL" "$TMPDIR/awscliv2.zip"

log_install "Unpacking..."
unzip -q "$TMPDIR/awscliv2.zip" -d "$TMPDIR"

if command -v aws >/dev/null 2>&1; then
    log_install "Updating existing AWS CLI..."
    sudo "$TMPDIR/aws/install" --update
else
    log_install "Installing AWS CLI to /usr/local..."
    sudo "$TMPDIR/aws/install"
fi

log_done
aws --version
