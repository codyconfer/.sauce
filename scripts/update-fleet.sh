#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

REPO="fleetdm/fleet"
DEST="$BIN/fleetctl"
FLEETD_PKG="fleet-osquery"

sauce_env() {
    [ -f "$SAUCE_DIR/.env" ] || return 0
    set -a
    # shellcheck disable=SC1091
    . "$SAUCE_DIR/.env"
    set +a
}

fleetd_installed() {
    case "$(detect_family)" in
        debian) grep -q "ok installed" <<<"$(dpkg-query -W -f='${Status}' "$FLEETD_PKG" 2>/dev/null)" ;;
        fedora) rpm -q "$FLEETD_PKG" >/dev/null 2>&1 ;;
        arch)   pacman -Qq "$FLEETD_PKG" >/dev/null 2>&1 ;;
        *)      [ -x /opt/orbit/bin/orbit/orbit ] ;;
    esac
}

fleetd_pkg_type() {
    case "$(detect_family)" in
        debian) echo deb ;;
        fedora) echo rpm ;;
        arch)   echo pkg.tar.zst ;;
        macos)  echo pkg ;;
        *)      return 1 ;;
    esac
}

cleanup() {
    log_clean "Removing fleetctl..."
    remove_paths "$DEST"
    remove_stamp fleetctl
    if fleetd_installed; then
        log_hint "fleetd is still enrolled; remove it with 'sudo <pkg-manager> remove $FLEETD_PKG' to unenroll this host."
    fi
    log_done "fleetctl removed."
}
dispatch_remove "$@"

log_search "Fetching the latest fleetctl version..."
LATEST=$(fetch "https://api.github.com/repos/$REPO/releases?per_page=30" \
    | jq -r '[.[] | select(.tag_name | startswith("fleet-v")) | .tag_name][0]')
if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
    log_error "Could not determine the latest fleetctl version."
    exit 1
fi
VERSION="${LATEST#fleet-}"
log_found "Latest version found: $VERSION"

case "$OS" in
    linux)  ASSET="fleetctl_${VERSION}_linux_${ARCH}.tar.gz" ;;
    darwin) ASSET="fleetctl_${VERSION}_macos.tar.gz" ;;
    *) log_error "unsupported OS for fleetctl: $OS"; exit 1 ;;
esac

INSTALLED=$(command -v fleetctl >/dev/null 2>&1 \
    && fleetctl --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)

if version_current "$INSTALLED" "$VERSION"; then
    log_done "fleetctl $INSTALLED is already the latest — skipping. (set FORCE=1 to reinstall)"
else
    TMPDIR=$(mktemp -d)
    trap 'rm -rf "$TMPDIR"' EXIT

    log_download "Downloading $ASSET..."
    download "https://github.com/$REPO/releases/download/$LATEST/$ASSET" "$TMPDIR/$ASSET"

    EXPECTED_SHA=$(fetch "https://github.com/$REPO/releases/download/$LATEST/checksums.txt" \
        | awk -v f="$ASSET" '$2==f || $2=="*"f {print $1}' | head -1)
    if [ -n "$EXPECTED_SHA" ]; then
        verify_sha256 "$EXPECTED_SHA" "$TMPDIR/$ASSET"
    else
        log_warn "No checksum published for $ASSET; skipping hash check."
    fi

    log_install "Installing fleetctl to $DEST..."
    tar -C "$TMPDIR" -xzf "$TMPDIR/$ASSET"
    FLEETCTL_BIN=$(find "$TMPDIR" -type f -name fleetctl -perm -u+x | head -1)
    [ -n "$FLEETCTL_BIN" ] || { log_error "fleetctl not found inside $ASSET."; exit 1; }
    ensure_dir "$BIN"
    install -m 0755 "$FLEETCTL_BIN" "$DEST"
    write_stamp fleetctl "$VERSION"
    log_done "fleetctl $VERSION installed -> $DEST"
fi

if fleetd_installed; then
    log_info "fleetd is already enrolled; orbit keeps it and Fleet Desktop updated over TUF."
    exit 0
fi

sauce_env
if [ -z "${FLEET_URL:-}" ] || [ -z "${FLEET_ENROLL_SECRET:-}" ]; then
    log_info "fleetd is not installed and no enrollment details were found."
    log_hint "Set FLEET_URL and FLEET_ENROLL_SECRET (in $SAUCE_DIR/.env) and re-run to build and install fleetd with Fleet Desktop."
    exit 0
fi

PKG_TYPE=$(fleetd_pkg_type) || { log_error "no fleetd package type for this distro."; exit 1; }
BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT

log_install "Building the fleetd package ($PKG_TYPE) with Fleet Desktop..."
(
    cd "$BUILD_DIR" || exit 1
    "$DEST" package --type="$PKG_TYPE" --fleet-desktop \
        --fleet-url="$FLEET_URL" --enroll-secret="$FLEET_ENROLL_SECRET"
) || { log_error "fleetctl package failed."; exit 1; }

FLEETD_FILE=$(find "$BUILD_DIR" -maxdepth 1 -type f -name "fleet-osquery*" | head -1)
[ -n "$FLEETD_FILE" ] || { log_error "fleetctl package produced no installer."; exit 1; }

log_install "Installing $(basename "$FLEETD_FILE")..."
install_local_pkg "$FLEETD_FILE" || { log_error "fleetd install failed."; exit 1; }

log_done "fleetd enrolled against $FLEET_URL."
log_hint "orbit now self-updates over TUF; re-run this script only to refresh fleetctl."
