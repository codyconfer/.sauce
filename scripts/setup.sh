#! /bin/bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/runner.sh"

FAMILY=$(detect_family)

if [ "$FAMILY" = unknown ]; then
    log_error "Unsupported distro (need apt, dnf, or pacman). For macOS use $SAUCE_DIR/macos/setup.sh."
    exit 1
fi
log_info "Detected distro family: $FAMILY"

hush_login() {
    touch ~/.hushlogin
    log_done "Login banner hushed."
}

github_auth() {
    command -v gh >/dev/null 2>&1 || { log_warn "gh not installed; skipping GitHub auth."; return 0; }
    gh auth status >/dev/null 2>&1 || gh auth login -p ssh || return 1
    gh auth setup-git || return 1
    if [ ! -d "$SAUCE_DIR" ]; then
        log_download "Cloning $SAUCE_DIR config repo..."
        git clone "git@github.com:$GITHUB_USER/.sauce.git" "$SAUCE_DIR" || return 1
    fi
}

oh_my_posh() {
    fetch https://ohmyposh.dev/install.sh | bash -s
}

configure_shell() {
    bash "$SCRIPT_DIR/stow.sh" || return 1
    chsh -s "$(command -v zsh)" || log_warn "chsh failed; set zsh as your login shell manually."
}

tailscale_up() {
    if ! command -v tailscale >/dev/null 2>&1; then
        log_download "Installing Tailscale..."
        fetch https://tailscale.com/install.sh | sh || return 1
    fi
    sudo tailscale up
}

run_step "hush login"      hush_login
run_step "base packages"   bash "$SCRIPT_DIR/install-base.sh"
run_step "github auth"     github_auth
run_step "oh-my-posh"      oh_my_posh
run_install_scripts "$SCRIPT_DIR"
run_update_scripts "$SCRIPT_DIR"
run_step "neovim config"   bash "$SCRIPT_DIR/build-nvim.sh"
run_step "sway config"     bash "$SCRIPT_DIR/build-sway.sh"
run_step "configure shell" configure_shell
run_step "tailscale"       tailscale_up

print_summary
