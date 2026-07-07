#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

case "$(detect_family)" in
    fedora|arch)
        install_pkgs firefox
        ;;
    debian)
        log_install "Configuring Mozilla's APT repository..."
        sudo install -d -m 0755 /etc/apt/keyrings
        fetch https://packages.mozilla.org/apt/repo-signing-key.gpg \
            | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc >/dev/null
        echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
            | sudo tee /etc/apt/sources.list.d/mozilla.list >/dev/null
        printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' \
            | sudo tee /etc/apt/preferences.d/mozilla >/dev/null
        sudo apt update
        install_pkgs firefox
        ;;
    *)
        log_error "unsupported distro (need apt, dnf, or pacman)."
        exit 1
        ;;
esac

log_done
command -v firefox >/dev/null && firefox --version || true
