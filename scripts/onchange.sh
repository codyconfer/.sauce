#!/usr/bin/env bash
# Idempotent, re-runnable steps for ~/.sauce (things that should re-run when their
# inputs change).
#
# Invoked two ways:
#   1. During `chezmoi apply` by the home/.chezmoiscripts/run_onchange_* wrappers, which
#      pass the current selection as env vars and embed a hash of this file so chezmoi
#      re-runs the step when either the selection or this logic changes.
#   2. Manually via the generated `onchange` alias (`onchange`, `onchange flatpaks`, ...),
#      falling back to `chezmoi data` for any value the env doesn't provide.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# _data <jq args...> — read a value from chezmoi's merged template data (fallback path
# for manual runs only; the apply path always passes env vars). Never called mid-apply.
_data() { chezmoi data --format json 2>/dev/null | jq -r "$@" 2>/dev/null || true; }

onchange_distro_apps() {
    local family
    family="${FAMILY:-$(detect_family)}"

    local -a apps sway_pkgs
    if [ -n "${DISTRO_APPS+x}" ]; then
        read -ra apps <<<"${DISTRO_APPS:-}"
    else
        mapfile -t apps < <(_data '.distroApps[]?')
    fi
    if [ -n "${SWAY_PKGS+x}" ]; then
        read -ra sway_pkgs <<<"${SWAY_PKGS:-}"
    else
        mapfile -t sway_pkgs < <(_data '.sway.common[]?')
    fi

    _has() { local x; for x in "${apps[@]:-}"; do [ "$x" = "$1" ] && return 0; done; return 1; }

    log_info "Installing selected distro desktop apps: ${apps[*]:-(none)}"

    if _has fish; then
        install_pkgs fish || log_warn "fish install failed."
    fi

    if _has firefox; then
        case "$family" in
            macos)
                install_cask firefox || log_warn "firefox install failed." ;;
            fedora|arch)
                install_pkgs firefox || log_warn "firefox install failed." ;;
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
                install_pkgs firefox || log_warn "firefox install failed." ;;
        esac
    fi

    if _has steam; then
        case "$family" in
            macos)
                install_cask steam || log_warn "steam install failed." ;;
            debian)
                log_install "Enabling i386 multiarch for Steam..."
                sudo dpkg --add-architecture i386
                sudo apt update
                local pkgpath="$CACHE/steam_latest.deb"
                ensure_dir "$CACHE"
                log_download "Downloading the Steam installer..."
                download "https://repo.steampowered.com/steam/archive/stable/steam_latest.deb" "$pkgpath"
                install_local_pkg "$pkgpath" || log_warn "steam install failed."
                rm -f "$pkgpath" ;;
            fedora)
                log_install "Enabling RPM Fusion for Steam..."
                sudo dnf install -y \
                    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
                    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" || true
                install_pkgs steam || log_warn "steam install failed." ;;
            arch)
                if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
                    log_install "Enabling the multilib repo in /etc/pacman.conf..."
                    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
                    sudo pacman -Sy
                fi
                install_pkgs steam || log_warn "steam install failed." ;;
        esac
    fi

    if _has wine; then
        case "$family" in
            macos)
                install_cask wine-stable || log_warn "wine install failed." ;;
            debian)
                log_install "Enabling i386 multiarch for Wine..."
                sudo dpkg --add-architecture i386
                sudo apt update
                install_pkgs wine wine32:i386 wine64 || log_warn "wine install failed." ;;
            fedora)
                install_pkgs wine || log_warn "wine install failed." ;;
            arch)
                if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
                    log_install "Enabling the multilib repo in /etc/pacman.conf..."
                    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
                    sudo pacman -Sy
                fi
                install_pkgs wine || log_warn "wine install failed." ;;
        esac
    fi

    if _has sway; then
        if [ "$family" = macos ]; then
            log_info "sway (Wayland WM) is Linux-only — skipping on macOS."
        else
            log_install "Installing sway and companions..."
            install_pkgs "${sway_pkgs[@]:-}" || log_warn "sway stack partial install."
            case "$family" in
                debian) install_pkgs mako-notifier || log_warn "mako install failed." ;;
                *)      install_pkgs mako || log_warn "mako install failed." ;;
            esac
        fi
    fi

    if _has qemu; then
        log_install "Installing QEMU..."
        case "$family" in
            debian) install_pkgs qemu-system qemu-utils libvirt-daemon-system libvirt-clients virt-manager bridge-utils ovmf || log_warn "qemu install failed." ;;
            fedora) install_pkgs qemu-kvm libvirt virt-manager virt-install edk2-ovmf || log_warn "qemu install failed." ;;
            arch)   install_pkgs qemu-full libvirt virt-manager dnsmasq edk2-ovmf || log_warn "qemu install failed." ;;
            macos)  install_pkgs qemu || log_warn "qemu install failed." ;;
        esac
        if [ "$family" != macos ]; then
            if command -v systemctl >/dev/null 2>&1; then
                sudo systemctl enable --now libvirtd || log_warn "could not enable libvirtd."
            fi
            sudo usermod -aG libvirt "$USER" || log_warn "could not add $USER to libvirt group."
            log_hint "Log out and back in for libvirt group membership to take effect."
        fi
    fi

    log_done "Distro desktop apps installed."
}

onchange_flatpaks() {
    if [ "$(detect_family)" = macos ]; then
        onchange_casks
        return $?
    fi

    local -a ids
    if [ -n "${FLATPAK_IDS+x}" ]; then
        read -ra ids <<<"${FLATPAK_IDS:-}"
    else
        mapfile -t ids < <(_data '.flatpaks[] as $k | .flatpakCatalog[$k] // empty')
    fi

    if [ "${#ids[@]}" -eq 0 ]; then
        log_info "no flatpaks selected — skipping."
        return 0
    fi
    log_info "Installing/updating selected Flathub apps..."
    local id
    for id in "${ids[@]}"; do
        install_flatpak "$id" || log_warn "flatpak install failed: $id"
    done
    log_done "Flatpaks installed."
}

onchange_casks() {
    local -a casks
    if [ -n "${FLATPAK_CASKS+x}" ]; then
        read -ra casks <<<"${FLATPAK_CASKS:-}"
    else
        mapfile -t casks < <(_data '.flatpaks[] as $k | .caskCatalog[$k] // empty')
    fi

    if [ "${#casks[@]}" -eq 0 ]; then
        log_info "no macOS casks selected — skipping."
        return 0
    fi
    log_info "Installing/updating selected apps via Homebrew casks..."
    local c
    for c in "${casks[@]}"; do
        install_cask "$c" || log_warn "cask install failed: $c"
    done
    log_done "Casks installed."
}

onchange_net_tools() {
    local -a pkgs
    if [ -n "${NET_TOOLS+x}" ]; then
        # Apply path: the wrapper only sets NET_TOOLS when the netTools prompt is on.
        read -ra pkgs <<<"${NET_TOOLS:-}"
    else
        # Manual path: honor the bool, then resolve the per-family list from data.
        [ "$(_data '.netTools')" = true ] || { log_info "netTools=false — skipping."; return 0; }
        local family
        family="${FAMILY:-$(detect_family)}"
        mapfile -t pkgs < <(_data --arg f "$family" '.packages.netTools.common + (.packages.netTools[$f] // []) | .[]')
    fi

    if [ "${#pkgs[@]}" -eq 0 ]; then
        log_info "no network tools to install — skipping."
        return 0
    fi

    log_install "Installing network/security tools (best-effort): ${pkgs[*]}"
    pkg_refresh || true
    local p
    for p in "${pkgs[@]}"; do
        install_pkgs "$p" || log_warn "skipped (unavailable): $p"
    done
    log_done "Network tools installed."
}

onchange_nvim_bootstrap() {
    if [ "${SKIP_NVIM_BOOTSTRAP:-0}" = "1" ]; then
        log_info "SKIP_NVIM_BOOTSTRAP=1 — skipping nvim plugin/server sync."
        return 0
    fi
    command -v nvim >/dev/null 2>&1 || { log_warn "nvim not found; skipping bootstrap."; return 0; }

    log_install "Syncing plugins (lazy.nvim)..."
    nvim --headless "+Lazy! sync" +qa </dev/null 2>&1 || log_warn "Lazy sync returned non-zero (often benign)."

    log_install "Installing treesitter parsers..."
    nvim --headless "+Lazy! load nvim-treesitter" \
        "+lua vim.cmd('TSInstallSync! '..table.concat(require('sauce.toolset').parsers,' '))" +qa </dev/null 2>&1 \
        || log_warn "Treesitter parser install returned non-zero."

    log_install "Installing LSP servers via Mason (may take a few minutes)..."
    nvim --headless "+Lazy! load nvim-lspconfig" \
        "+lua local done=false; vim.api.nvim_create_autocmd('User',{pattern='MasonToolsUpdateCompleted',callback=function() done=true end}); pcall(vim.cmd,'MasonToolsInstall'); vim.wait(240000,function() return done end,500)" \
        +qa </dev/null 2>&1 || log_warn "Mason install returned non-zero; run :Mason in nvim to finish."

    log_done "Neovim bootstrap complete."
}

case "${1:-all}" in
    distro-apps)    onchange_distro_apps ;;
    flatpaks)       onchange_flatpaks ;;
    net-tools)      onchange_net_tools ;;
    nvim-bootstrap) onchange_nvim_bootstrap ;;
    all)
        onchange_distro_apps
        onchange_flatpaks
        onchange_net_tools
        onchange_nvim_bootstrap
        ;;
    *) log_error "unknown onchange step: ${1:-}"; exit 2 ;;
esac
