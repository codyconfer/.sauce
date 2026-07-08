#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# qdmr ships only as a single-file flatpak bundle on GitHub (not on Flathub). We fetch
# the bundle and install it with `flatpak --user`; its KDE runtime is pulled from the
# flathub remote that ensure_flatpak configures.
APP_ID="de.darc.dm3mat.qdmr"
API="https://api.github.com/repos/hmatuschek/qdmr/releases/latest"

cleanup() {
    log_clean "Removing qdmr..."
    remove_flatpak "$APP_ID" || log_warn "flatpak uninstall failed (qdmr may not be installed)."
    remove_stamp qdmr
    log_done "qdmr removed."
}
dispatch_remove "$@"

log_search "Fetching the latest qdmr version..."
META=$(fetch "$API")
VERSION=$(echo "$META" | jq -r '.tag_name')
URL=$(echo "$META" | jq -r '.assets[] | select(.name | endswith(".flatpak.zip")) | .browser_download_url' | head -n1)
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ] || [ -z "$URL" ]; then
    log_error "Could not resolve the latest qdmr flatpak bundle."
    exit 1
fi
log_found "Latest version found: $VERSION"

# The bundle carries no queryable version; compare the release tag against the last install.
if [ -z "${FORCE:-}" ] \
    && flatpak info --user "$APP_ID" >/dev/null 2>&1 \
    && [ "$(read_stamp qdmr)" = "$VERSION" ]; then
    log_done "qdmr $VERSION is already installed — skipping. (set FORCE=1 to reinstall)"
    exit 0
fi

# Ensures flatpak is installed and the flathub --user remote exists (needed so flatpak
# can resolve the KDE runtime the bundle depends on).
ensure_flatpak || { log_error "flatpak is required to install qdmr."; exit 1; }

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log_download "Downloading qdmr $VERSION..."
download "$URL" "$TMPDIR/qdmr.flatpak.zip"

log_install "Unpacking the flatpak bundle..."
unzip -o -q "$TMPDIR/qdmr.flatpak.zip" -d "$TMPDIR"
BUNDLE=$(find "$TMPDIR" -maxdepth 1 -name '*.flatpak' | head -n1)
[ -n "$BUNDLE" ] || { log_error "No .flatpak bundle found in the archive."; exit 1; }

log_install "Installing $APP_ID via flatpak (user)..."
flatpak install --user -y --reinstall "$BUNDLE"
write_stamp qdmr "$VERSION"

log_done
log_hint "Launch QDMR from your app menu or run 'flatpak run $APP_ID'."
