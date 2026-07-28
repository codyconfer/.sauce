#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [ "$OS" = darwin ]; then macos_tool "${BASH_SOURCE[0]}" "$@"; exit $?; fi

KEYRING=/usr/share/keyrings/claude-desktop-archive-keyring.asc
SOURCES=/etc/apt/sources.list.d/claude-desktop.list
KEY_URL=https://downloads.claude.ai/claude-desktop/key.asc
REPO_URL=https://downloads.claude.ai/claude-desktop/apt/stable
FINGERPRINT=31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE

cleanup() {
    log_clean "Removing Claude Desktop..."
    remove_pkgs claude-desktop || log_warn "apt remove failed (claude-desktop may not be installed)."
    remove_sudo_paths "$SOURCES" "$KEYRING"
    log_done "Claude Desktop removed."
    log_hint "Config under ~/.config/Claude was left in place."
}
dispatch_remove "$@"

if [ "$(detect_family)" != debian ]; then
    log_error "Claude Desktop on Linux ships as an apt package — Ubuntu 22.04+ / Debian 12+ only."
    exit 1
fi

if [ "$ARCH" != amd64 ] && [ "$ARCH" != arm64 ]; then
    log_error "Claude Desktop publishes amd64 and arm64 only (this machine is $ARCH)."
    exit 1
fi

log_install "Configuring Anthropic's APT repository..."
sudo curl -fsSLo "$KEYRING" "$KEY_URL"
if command -v gpg >/dev/null 2>&1; then
    log_verify "Verifying the signing key fingerprint..."
    if ! gpg --show-keys --with-colons "$KEYRING" 2>/dev/null | grep -q "^fpr:::::::::$FINGERPRINT:"; then
        log_error "Signing key does not match Anthropic's published fingerprint."
        sudo rm -f "$KEYRING"
        exit 1
    fi
fi
echo "deb [arch=amd64,arm64 signed-by=$KEYRING] $REPO_URL stable main" \
    | sudo tee "$SOURCES" >/dev/null

log_search "Fetching the latest Claude Desktop version..."
sudo apt update
INSTALLED=$(dpkg-query -W -f='${Version}' claude-desktop 2>/dev/null || true)
VERSION=$(apt-cache policy claude-desktop 2>/dev/null | awk '/Candidate:/ {print $2}')
if [ -z "$VERSION" ] || [ "$VERSION" = "(none)" ]; then
    log_error "Could not resolve claude-desktop from the repository."
    exit 1
fi
log_found "Latest version found: $VERSION"

version_gate "Claude Desktop" "$INSTALLED" "$VERSION" && exit 0

log_install "Installing..."
# The package ships its own (commented-out) sources entry — keep ours without prompting.
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
    -o Dpkg::Options::=--force-confold claude-desktop

log_done
log_hint "Launch Claude from your app menu or run 'claude-desktop'."
