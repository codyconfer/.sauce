#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [ "$OS" = darwin ]; then macos_tool "${BASH_SOURCE[0]}" "$@"; exit $?; fi

case "$(detect_family)" in
    debian) PKG=docker-desktop-amd64.deb ;;
    fedora) PKG=docker-desktop-x86_64.rpm ;;
    arch)   PKG=docker-desktop-x86_64.pkg.tar.zst ;;
    *) log_error "unsupported distro (need apt, dnf, or pacman)."; exit 1 ;;
esac

cleanup() {
    log_clean "Removing Docker Desktop..."
    remove_pkgs docker-desktop
    log_done "Docker Desktop removed."
}
dispatch_remove "$@"

ensure_docker_cli() {
    local -a cli buildx
    local p ok=""
    case "$(detect_family)" in
        debian) cli=(docker-ce-cli docker.io);   buildx=(docker-buildx-plugin) ;;
        fedora) cli=(docker-ce-cli moby-engine); buildx=(docker-buildx-plugin) ;;
        arch)   cli=(docker);                    buildx=(docker-buildx) ;;
        *)      return 0 ;;
    esac

    if command -v docker >/dev/null 2>&1; then
        log_done "docker CLI already present ($(command -v docker))."
    else
        log_install "Installing the docker CLI..."
        for p in "${cli[@]}"; do
            if install_pkgs "$p" >/dev/null 2>&1; then ok="$p"; break; fi
        done
        if [ -z "$ok" ]; then
            log_warn "Could not install a docker CLI; Kubernetes (kind mode) will fail to start."
            return 1
        fi
        log_done "docker CLI ready ($ok)."
    fi

    docker buildx version >/dev/null 2>&1 && return 0
    log_install "Installing docker buildx..."
    for p in "${buildx[@]}"; do
        install_pkgs "$p" >/dev/null 2>&1 && { log_done "buildx ready ($p)."; return 0; }
    done
    log_warn "Could not install docker buildx; builds fall back to the legacy builder."
}

ensure_docker_cli || true

BASE=https://desktop.docker.com/linux/main/amd64
PKGPATH="$CACHE/$PKG"
HDRS=$(mktemp)
trap 'rm -f "$HDRS"' EXIT

ensure_dir "$CACHE"
log_download "Downloading $PKG..."
download_with_headers "$BASE/$PKG" "$PKGPATH" "$HDRS"

verify_md5_etag "$HDRS" "$PKGPATH"

log_install "Installing..."
install_local_pkg "$PKGPATH"

log_clean "Cleaning up downloaded package..."
rm "$PKGPATH"

if ! command -v docker >/dev/null 2>&1; then
    log_warn "No working 'docker' on PATH — Docker Desktop's Kubernetes will not start."
fi

log_done
command -v docker >/dev/null && docker --version || true
