#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [ "$OS" = darwin ]; then macos_tool "${BASH_SOURCE[0]}" "$@"; exit $?; fi

FAMILY=$(detect_family)
FLATPAK_ID="com.onepassword.OnePassword"
KEY_URL="https://downloads.1password.com/linux/keys/1password.asc"
DEBSIG_ID="AC2D62742012EA22"
APT_KEYRING="/usr/share/keyrings/1password-archive-keyring.gpg"
APT_LIST="/etc/apt/sources.list.d/1password.list"
DEBSIG_POLICY="/etc/debsig/policies/$DEBSIG_ID/1password.pol"
DEBSIG_KEYRING="/usr/share/debsig/keyrings/$DEBSIG_ID/debsig.gpg"
DNF_REPO="/etc/yum.repos.d/1password.repo"

cleanup() {
    log_clean "Removing 1Password..."
    remove_pkgs 1password || log_warn "package removal failed (1Password may not be installed)."
    case "$FAMILY" in
        debian) remove_sudo_paths "$APT_LIST" "$APT_KEYRING" "$DEBSIG_POLICY" "$DEBSIG_KEYRING" ;;
        fedora) remove_sudo_paths "$DNF_REPO" ;;
    esac
    log_done "1Password removed."
}
dispatch_remove "$@"

if command -v flatpak >/dev/null 2>&1 && flatpak info "$FLATPAK_ID" >/dev/null 2>&1; then
    log_warn "The sandboxed Flathub build ($FLATPAK_ID) is still installed."
    log_hint "Remove it so the native package owns the launcher: flatpak uninstall --user -y $FLATPAK_ID"
fi

case "$FAMILY" in
    debian)
        if [ -n "${FORCE:-}" ] || [ ! -f "$APT_LIST" ] || [ ! -f "$APT_KEYRING" ]; then
            log_install "Configuring 1Password's APT repository..."
            fetch "$KEY_URL" | sudo gpg --dearmor --yes --output "$APT_KEYRING"
            echo "deb [arch=$ARCH signed-by=$APT_KEYRING] https://downloads.1password.com/linux/debian/$ARCH stable main" \
                | sudo tee "$APT_LIST" >/dev/null
            sudo install -d -m 0755 "$(dirname "$DEBSIG_POLICY")" "$(dirname "$DEBSIG_KEYRING")"
            fetch "https://downloads.1password.com/linux/debian/debsig/1password.pol" \
                | sudo tee "$DEBSIG_POLICY" >/dev/null
            fetch "$KEY_URL" | sudo gpg --dearmor --yes --output "$DEBSIG_KEYRING"
            pkg_refresh
        fi
        install_pkgs 1password
        ;;
    fedora)
        if [ -n "${FORCE:-}" ] || [ ! -f "$DNF_REPO" ]; then
            log_install "Configuring 1Password's DNF repository..."
            sudo rpm --import "$KEY_URL"
            printf '[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey="%s"\n' \
                "$KEY_URL" | sudo tee "$DNF_REPO" >/dev/null
        fi
        install_pkgs 1password
        ;;
    arch)
        HELPER=""
        for h in paru yay; do
            command -v "$h" >/dev/null 2>&1 && { HELPER="$h"; break; }
        done
        if [ -z "$HELPER" ]; then
            log_error "1Password ships as the AUR package '1password' — install paru or yay first."
            exit 1
        fi
        log_install "Installing 1Password from the AUR via $HELPER..."
        "$HELPER" -S --needed --noconfirm 1password
        ;;
    *)
        log_error "unsupported distro (need apt, dnf, or pacman)."
        exit 1
        ;;
esac

log_done
log_hint "1Password updates with the system — the 'update' alias upgrades it along with everything else."
