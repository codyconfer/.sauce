#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

_data() { chezmoi data --format json 2>/dev/null | jq -r "$@" 2>/dev/null || true; }

setup_base_packages() {
    local family
    family="${FAMILY:-$(detect_family)}"
    if [ "$family" = unknown ]; then
        log_error "unsupported distro (need apt, dnf, or pacman)."
        return 1
    fi
    log_info "Installing base packages for family: $family"

    local -a essential extras
    if [ -n "${ESSENTIAL:-}" ]; then
        read -ra essential <<<"$ESSENTIAL"
    else
        mapfile -t essential < <(_data --arg f "$family" '.packages.essential.common + (.packages.essential[$f] // []) | .[]')
    fi
    if [ -n "${EXTRAS:-}" ]; then
        read -ra extras <<<"$EXTRAS"
    else
        mapfile -t extras < <(_data '.packages.extras.common[]')
    fi
    [ "$family" = arch ] && extras=("${extras[@]/pipx/python-pipx}")

    pkg_refresh || true

    log_install "Installing essential packages..."
    install_pkgs "${essential[@]}" || { log_error "Failed to install essential packages."; return 1; }

    log_install "Installing extra packages (best-effort)..."
    local p
    for p in "${extras[@]}"; do
        install_pkgs "$p" || log_warn "skipped (unavailable): $p"
    done

    command -v pipx   >/dev/null 2>&1 && pipx ensurepath || true

    log_done "Base packages installed."
}

setup_github_auth() {
    command -v gh >/dev/null 2>&1 || { log_warn "gh not installed; skipping GitHub auth."; return 0; }

    if gh auth status >/dev/null 2>&1; then
        log_info "GitHub already authenticated."
    else
        log_info "Authenticating with GitHub over SSH..."
        gh auth login -p ssh || { log_warn "gh auth login failed or was skipped."; return 0; }
    fi
    gh auth setup-git || log_warn "gh auth setup-git failed."
}

setup_oh_my_posh() {
    if command -v oh-my-posh >/dev/null 2>&1; then
        log_info "oh-my-posh already installed."
        return 0
    fi
    log_download "Installing oh-my-posh..."
    fetch https://ohmyposh.dev/install.sh | bash -s
}

setup_run_updaters() {
    if [ ! -f "$HOME/.sauce/scripts/update-all.sh" ]; then
        log_warn "scripts/update-all.sh not found; skipping updaters."
        return 0
    fi
    log_found "Running self-updating tool installers (scripts/update-all.sh)..."
    bash "$HOME/.sauce/scripts/update-all.sh" \
        || log_warn "Some updaters failed; re-run individually (e.g. 'update-go') or 'update-all'."
}

setup_chsh_zsh() {
    local zsh_path
    zsh_path="$(command -v zsh || true)"
    [ -z "$zsh_path" ] && { log_warn "zsh not found; skipping chsh."; return 0; }
    if [ "${SHELL:-}" = "$zsh_path" ]; then
        log_info "Login shell already zsh."
        return 0
    fi
    log_info "Setting zsh as your login shell..."
    chsh -s "$zsh_path" || log_warn "chsh failed; set zsh as your login shell manually."
}

setup_sway_session() {
    # Stages a greetd + tuigreet + uwsm login stack for sway WITHOUT switching
    # the active display manager. Switch later with:
    #   sudo systemctl disable <current-dm> && sudo systemctl enable greetd
    if [ "${SWAY_SESSION:-}" != 1 ]; then
        local sel
        sel="$(_data '.guiApps | index("sway")')"
        if [ -z "$sel" ] || [ "$sel" = null ]; then
            log_info "sway not selected — skipping the sway session stack."
            return 0
        fi
    fi

    local family
    family="${FAMILY:-$(detect_family)}"
    if [ "$family" = macos ]; then
        log_info "sway session stack is Linux-only — skipping on macOS."
        return 0
    fi

    log_info "Staging the sway login stack (greetd + tuigreet + uwsm)..."

    # Find the active display manager so installing greetd does not steal
    # display-manager.service (Debian's greetd postinst asks via debconf).
    local current_dm=""
    if [ -f /etc/X11/default-display-manager ]; then
        current_dm="$(basename "$(cat /etc/X11/default-display-manager)")"
    elif [ -L /etc/systemd/system/display-manager.service ]; then
        current_dm="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)" .service)"
    fi

    case "$family" in
        debian)
            # Preseed is a no-op when the greetd package ships no debconf
            # template (true on Ubuntu 26.04) — harmless belt-and-suspenders
            # for derivatives whose packaging does ask.
            if [ -n "$current_dm" ]; then
                echo "greetd shared/default-x-display-manager select $current_dm" \
                    | sudo debconf-set-selections || true
            fi
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y greetd \
                || { log_warn "greetd install failed."; return 1; }
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y tuigreet \
                || log_warn "tuigreet install failed; greetd will fall back to agreety."
            ;;
        fedora|arch)
            install_pkgs greetd || { log_warn "greetd install failed."; return 1; }
            install_pkgs greetd-tuigreet || install_pkgs tuigreet \
                || log_warn "tuigreet install failed; greetd will fall back to agreety."
            ;;
    esac

    # Greeter user differs per distro (_greetd on Debian/Ubuntu, greetd on
    # Fedora, greeter on Arch); prefer whatever the existing config declares —
    # packaged or a previous sauce run — over the family default.
    local greet_user
    case "$family" in
        fedora) greet_user="greetd" ;;
        arch)   greet_user="greeter" ;;
        *)      greet_user="_greetd" ;;
    esac
    if [ -f /etc/greetd/config.toml ]; then
        local existing_user
        existing_user="$(sudo grep -Po '^\s*user\s*=\s*"\K[^"]+' /etc/greetd/config.toml | grep -vx "$USER" | tail -n1 || true)"
        [ -n "$existing_user" ] && greet_user="$existing_user"
        if ! sudo grep -q "managed by sauce" /etc/greetd/config.toml; then
            sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.dist-bak
            log_info "Backed up the packaged greetd config to /etc/greetd/config.toml.dist-bak."
        fi
    fi

    local greeter_cmd="agreety --cmd 'uwsm start -- sway'"
    command -v tuigreet >/dev/null 2>&1 && greeter_cmd="tuigreet --time --remember --remember-session --sessions /usr/share/wayland-sessions:/usr/local/share/wayland-sessions --cmd 'uwsm start -- sway'"

    sudo tee /etc/greetd/config.toml >/dev/null <<-EOF
	# managed by sauce (chezmoi) — sway login stack, staged while $current_dm stays active
	[terminal]
	vt = 1

	# Once-per-boot autologin straight into sway (inert until greetd is the
	# active display manager); logging out falls back to the greeter below.
	[initial_session]
	command = "uwsm start -- sway"
	user = "$USER"

	[default_session]
	command = "$greeter_cmd"
	user = "$greet_user"
	EOF

    if command -v tuigreet >/dev/null 2>&1; then
        sudo mkdir -p /var/cache/tuigreet
        sudo chown "$greet_user":"$greet_user" /var/cache/tuigreet 2>/dev/null \
            || sudo chown "$greet_user" /var/cache/tuigreet || true
        sudo chmod 0755 /var/cache/tuigreet
    fi

    # "Sway (UWSM)" session entry — selectable from the current DM immediately.
    sudo tee /usr/share/wayland-sessions/sway-uwsm.desktop >/dev/null <<-'EOF'
	[Desktop Entry]
	Name=Sway (UWSM)
	Comment=Sway tiling Wayland compositor, managed by uwsm
	Exec=uwsm start -- sway
	Type=Application
	EOF

    local dm_now=""
    [ -L /etc/systemd/system/display-manager.service ] \
        && dm_now="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)" .service)"
    if [ -n "$current_dm" ] && [ "$dm_now" != "$current_dm" ]; then
        log_warn "display-manager.service changed ($current_dm -> ${dm_now:-none}); revert with: sudo systemctl disable ${dm_now:-greetd} && sudo systemctl enable $current_dm"
    else
        log_done "sway login stack staged; ${current_dm:-your display manager} is still in charge."
    fi
    log_hint "Boot straight into sway later with: sudo systemctl disable ${current_dm:-sddm} && sudo systemctl enable greetd"
}

setup_tailscale() {
    local on
    on="${TAILSCALE:-$(_data '.tailscale')}"
    if [ "$on" != true ]; then
        log_info "tailscale=false — skipping Tailscale setup."
        return 0
    fi
    if ! command -v tailscale >/dev/null 2>&1; then
        if [ "$(uname -s)" = Darwin ]; then
            log_download "Installing Tailscale (Homebrew cask)..."
            install_cask tailscale || { log_warn "tailscale install failed."; return 0; }
            log_hint "On macOS, bring up Tailscale from the menu-bar app (the 'tailscale' CLI is inside Tailscale.app)."
            return 0
        fi
        log_download "Installing Tailscale..."
        fetch https://tailscale.com/install.sh | sh || { log_warn "tailscale install failed."; return 0; }
    fi
    sudo tailscale up
}

case "${1:-all}" in
    base-packages) setup_base_packages ;;
    github-auth)   setup_github_auth ;;
    oh-my-posh)    setup_oh_my_posh ;;
    run-updaters)  setup_run_updaters ;;
    sway-session)  setup_sway_session ;;
    chsh-zsh)      setup_chsh_zsh ;;
    tailscale)     setup_tailscale ;;
    all)
        setup_base_packages
        setup_github_auth
        setup_oh_my_posh
        setup_run_updaters
        setup_sway_session
        setup_chsh_zsh
        setup_tailscale
        ;;
    *) log_error "unknown setup step: ${1:-}"; exit 2 ;;
esac
