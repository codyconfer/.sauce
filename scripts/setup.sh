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

LEMURS_REPO="coastalwhite/lemurs"
LEMURS_TARBALL="lemurs-x86_64-unknown-linux-gnu.tar.xz"

lemurs_version() {
    command -v lemurs >/dev/null 2>&1 || return 0
    lemurs --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

lemurs_files_present() {
    [ -f /etc/lemurs/config.toml ] && [ -f /etc/pam.d/lemurs ] && {
        [ -f /usr/lib/systemd/system/lemurs.service ] \
            || [ -f /etc/systemd/system/lemurs.service ]
    }
}

lemurs_fetch_extra() {
    local ref="$1" tmp="$2" f
    ensure_dir "$tmp/extra"
    for f in config.toml xsetup.sh lemurs.pam lemurs.service; do
        fetch "https://raw.githubusercontent.com/$LEMURS_REPO/$ref/extra/$f" \
            >"$tmp/extra/$f" || return 1
    done
    LEMURS_EXTRA="$tmp/extra"
}

lemurs_from_source() {
    local latest="$1" tmp="$2"
    log_info "No lemurs release build for $(uname -m) — building from source (cargo)."
    install_pkgs libpam0g-dev || install_pkgs pam-devel || install_pkgs pam || true
    command -v cargo >/dev/null 2>&1 || install_pkgs cargo || install_pkgs rust || return 1
    cargo install --locked --git "https://github.com/$LEMURS_REPO" --tag "$latest" \
        --root "$tmp/cargo" || return 1
    sudo install -Dm0755 "$tmp/cargo/bin/lemurs" /usr/bin/lemurs || return 1
    lemurs_fetch_extra "$latest" "$tmp"
}

lemurs_from_release() {
    local latest="$1" tmp="$2" base expected dir
    base="https://github.com/$LEMURS_REPO/releases/download/$latest"
    dir="$tmp/${LEMURS_TARBALL%.tar.xz}"

    log_download "Downloading lemurs $latest..."
    download "$base/$LEMURS_TARBALL" "$tmp/$LEMURS_TARBALL" || return 1
    expected="$(fetch "$base/sha256.sum" \
        | awk -v f="$LEMURS_TARBALL" '$2 == f || $2 == "*"f {print $1}' | head -1)"
    if [ -n "$expected" ]; then
        verify_sha256 "$expected" "$tmp/$LEMURS_TARBALL" || return 1
    else
        log_warn "No checksum published for $LEMURS_TARBALL; skipping hash check."
    fi
    tar -C "$tmp" -xJf "$tmp/$LEMURS_TARBALL" || return 1
    sudo install -Dm0755 "$dir/lemurs" /usr/bin/lemurs || return 1
    LEMURS_EXTRA="$dir/extra"
}

install_lemurs() {
    local family="$1" tmp="$2" latest
    LEMURS_EXTRA=""

    latest="$(fetch "https://api.github.com/repos/$LEMURS_REPO/releases/latest" | jq -r '.tag_name')"
    if [ -z "$latest" ] || [ "$latest" = null ]; then
        log_error "Could not determine the latest lemurs version."
        return 1
    fi

    if [ "$family" = arch ] && install_pkgs lemurs; then
        log_done "lemurs installed from the Arch repos."
        lemurs_files_present || lemurs_fetch_extra "$latest" "$tmp"
        return 0
    fi

    if version_gate "lemurs" "$(lemurs_version)" "$latest"; then
        lemurs_files_present || lemurs_fetch_extra "$latest" "$tmp"
        return 0
    fi

    if [ "$(uname -m)" = x86_64 ]; then
        lemurs_from_release "$latest" "$tmp" || return 1
    else
        lemurs_from_source "$latest" "$tmp" || return 1
    fi
    log_done "lemurs $latest installed -> /usr/bin/lemurs"
}

stage_lemurs_files() {
    sudo mkdir -p /etc/lemurs/wayland /etc/lemurs/wms
    [ -n "${LEMURS_EXTRA:-}" ] || return 0

    if [ ! -f /etc/lemurs/config.toml ]; then
        sudo install -Dm0644 "$LEMURS_EXTRA/config.toml" /etc/lemurs/config.toml
        log_info "Installed the stock lemurs config to /etc/lemurs/config.toml."
    fi
    [ -f /etc/lemurs/xsetup.sh ] \
        || sudo install -Dm0755 "$LEMURS_EXTRA/xsetup.sh" /etc/lemurs/xsetup.sh
    [ -f /etc/pam.d/lemurs ] \
        || sudo install -Dm0644 "$LEMURS_EXTRA/lemurs.pam" /etc/pam.d/lemurs
    if [ ! -f /usr/lib/systemd/system/lemurs.service ] \
        && [ ! -f /etc/systemd/system/lemurs.service ]; then
        sudo install -Dm0644 "$LEMURS_EXTRA/lemurs.service" /etc/systemd/system/lemurs.service
        sudo systemctl daemon-reload || true
    fi
}

write_uwsm_session() {
    local id="$1" name="$2" comment="$3" desktop_names="$4" cmd="$5"
    sudo mkdir -p /usr/local/share/wayland-sessions /etc/lemurs/wayland
    sudo tee "/usr/local/share/wayland-sessions/$id.desktop" >/dev/null <<-EOF
	[Desktop Entry]
	Name=$name
	Comment=$comment
	Exec=$cmd
	TryExec=uwsm
	Type=Application
	DesktopNames=$desktop_names
	EOF
    printf '#!/bin/sh\nexec %s\n' "$cmd" | sudo tee "/etc/lemurs/wayland/$id" >/dev/null
    sudo chmod 0755 "/etc/lemurs/wayland/$id"
}

retire_session_entry() {
    local entry="$1"
    if ! command -v dpkg-divert >/dev/null 2>&1; then
        [ -e "$entry" ] || return 0
        sudo rm -f "$entry"
        log_clean "Removed $entry."
        return 0
    fi
    [ -n "$(dpkg-divert --list "$entry")" ] && return 0
    [ -e "$entry" ] || return 0
    sudo dpkg-divert --add --rename --divert "$entry.sauce-disabled" "$entry" >/dev/null
    log_clean "Diverted $entry (restore with: sudo dpkg-divert --remove $entry)."
}

retire_greetd() {
    local current_dm="$1"
    [ "$current_dm" = greetd ] && return 0
    [ -f /etc/greetd/config.toml ] || return 0
    sudo grep -q "managed by sauce" /etc/greetd/config.toml || return 0
    if [ -f /etc/greetd/config.toml.dist-bak ]; then
        sudo mv -f /etc/greetd/config.toml.dist-bak /etc/greetd/config.toml
        log_clean "Restored the packaged greetd config; sauce no longer manages greetd."
    else
        sudo rm -f /etc/greetd/config.toml
        log_clean "Removed the sauce-managed /etc/greetd/config.toml."
    fi
    log_hint "greetd is unused now — uninstall it with your package manager if you want it gone."
}

setup_sway_session() {
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

    log_info "Staging the sway login stack (lemurs + uwsm)..."

    local current_dm=""
    if [ -f /etc/X11/default-display-manager ]; then
        current_dm="$(basename "$(cat /etc/X11/default-display-manager)")"
    elif [ -L /etc/systemd/system/display-manager.service ]; then
        current_dm="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)" .service)"
    fi

    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"; trap - RETURN' RETURN

    install_lemurs "$family" "$tmp" || { log_warn "lemurs install failed."; return 1; }
    stage_lemurs_files

    write_uwsm_session sway "Sway" \
        "Sway tiling Wayland compositor, managed by uwsm" \
        "sway" \
        "uwsm start -N Sway -D sway -e -- sway"
    sudo rm -f /usr/share/wayland-sessions/sway-uwsm.desktop

    if command -v startplasma-wayland >/dev/null 2>&1; then
        write_uwsm_session plasma-uwsm "Plasma (UWSM)" \
            "KDE Plasma Wayland session, managed by uwsm" \
            "KDE" \
            "uwsm start -N Plasma -D KDE -e -- startplasma-wayland"
        log_info "Added a UWSM wrapper for the KDE Plasma Wayland session."
        retire_session_entry /usr/share/wayland-sessions/plasma.desktop
    fi

    retire_greetd "$current_dm"

    local dm_now=""
    [ -L /etc/systemd/system/display-manager.service ] \
        && dm_now="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)" .service)"
    if [ -n "$current_dm" ] && [ "$dm_now" != "$current_dm" ]; then
        log_warn "display-manager.service changed ($current_dm -> ${dm_now:-none}); revert with: sudo systemctl disable ${dm_now:-lemurs} && sudo systemctl enable $current_dm"
    else
        log_done "sway login stack staged; ${current_dm:-your display manager} is still in charge."
    fi
    log_hint "Boot into lemurs later with: sudo systemctl disable ${current_dm:-sddm} && sudo systemctl enable lemurs"
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
