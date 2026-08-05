#! /bin/bash

detect_family() {
    if [ "$(uname -s)" = Darwin ]; then
        echo macos
    elif command -v apt-get >/dev/null 2>&1; then
        echo debian
    elif command -v dnf >/dev/null 2>&1; then
        echo fedora
    elif command -v pacman >/dev/null 2>&1; then
        echo arch
    else
        echo unknown
    fi
}

install_local_pkg() {
    local file="$1"
    case "$(detect_family)" in
        debian) sudo apt install -y "$file" ;;
        fedora) sudo dnf install -y "$file" ;;
        arch)   sudo pacman -U --noconfirm "$file" ;;
        macos)  ensure_brew && brew install --cask "$file" ;;
        *) echo "❌ Error: unsupported distro (need apt, dnf, pacman, or brew)." >&2; return 1 ;;
    esac
}

pkg_refresh() {
    case "$(detect_family)" in
        debian) sudo apt update ;;
        fedora) sudo dnf check-update || true ;;
        arch)   sudo pacman -Sy ;;
        macos)  ensure_brew && brew update ;;
        *) echo "❌ Error: unsupported distro (need apt, dnf, pacman, or brew)." >&2; return 1 ;;
    esac
}

install_pkgs() {
    case "$(detect_family)" in
        debian) sudo apt install -y "$@" ;;
        fedora) sudo dnf install -y "$@" ;;
        arch)   sudo pacman -S --needed --noconfirm "$@" ;;
        macos)  ensure_brew && brew install "$@" ;;
        *) echo "❌ Error: unsupported distro (need apt, dnf, pacman, or brew)." >&2; return 1 ;;
    esac
}

remove_pkgs() {
    case "$(detect_family)" in
        debian) sudo apt remove -y "$@" ;;
        fedora) sudo dnf remove -y "$@" ;;
        arch)   sudo pacman -Rns --noconfirm "$@" ;;
        macos)  ensure_brew && brew uninstall "$@" ;;
        *) echo "❌ Error: unsupported distro (need apt, dnf, pacman, or brew)." >&2; return 1 ;;
    esac
}

ensure_libfuse2() {
    grep -q 'libfuse\.so\.2' <<<"$(ldconfig -p 2>/dev/null)" && return 0
    local -a candidates
    case "$(detect_family)" in
        debian) candidates=(libfuse2t64 libfuse2) ;;
        fedora) candidates=(fuse-libs) ;;
        arch)   candidates=(fuse2) ;;
        *)      return 0 ;;
    esac
    log_install "Installing libfuse2 (required to run AppImages)..."
    local p
    for p in "${candidates[@]}"; do
        if install_pkgs "$p" >/dev/null 2>&1; then
            log_done "libfuse2 ready ($p)."
            return 0
        fi
    done
    log_warn "Could not install libfuse2; AppImages will fail to launch until it is present."
    return 1
}

ensure_rpmfusion() {
    [ "$(detect_family)" = fedora ] || return 0
    rpm -q rpmfusion-free-release >/dev/null 2>&1 && return 0
    log_install "Enabling RPM Fusion (free + nonfree)..."
    sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
}

ensure_brew() {
    command -v brew >/dev/null 2>&1 && return 0
    local b
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [ -x "$b" ] && { eval "$("$b" shellenv)"; break; }
    done
    command -v brew >/dev/null 2>&1 && return 0
    log_download "Installing Homebrew..."
    NONINTERACTIVE=1 bash -c "$(fetch https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
        || { log_error "Homebrew install failed."; return 1; }
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [ -x "$b" ] && { eval "$("$b" shellenv)"; break; }
    done
    command -v brew >/dev/null 2>&1
}

install_cask() { ensure_brew && brew install --cask "$@"; }

_brew_spec() {
    case "$1" in
        1password)         echo "cask 1password" ;;
        1password-cli)     echo "cask 1password-cli" ;;
        adb)               echo "cask android-platform-tools" ;;
        aws)               echo "formula awscli" ;;
        bitwarden)         echo "cask bitwarden" ;;
        bitwarden-cli)     echo "formula bitwarden-cli" ;;
        claude)            echo "cask claude" ;;
        cloudflared)       echo "formula cloudflared" ;;
        cursor)            echo "cask cursor" ;;
        docker)            echo "cask docker" ;;
        gcloud)            echo "cask google-cloud-sdk" ;;
        ghidra)            echo "cask ghidra" ;;
        go)                echo "formula go" ;;
        jetbrains-toolbox) echo "cask jetbrains-toolbox" ;;
        k9s)               echo "formula k9s" ;;
        kubectl)           echo "formula kubernetes-cli" ;;
        lmstudio)          echo "cask lm-studio" ;;
        nvim)              echo "formula neovim" ;;
        obsidian)          echo "cask obsidian" ;;
        ollama)            echo "cask ollama" ;;
        qdmr)              echo "cask qdmr" ;;
        tmux)              echo "formula tmux" ;;
        vscode)            echo "cask visual-studio-code" ;;
        *) return 1 ;;
    esac
}

macos_tool() {
    local script="$1"; shift
    local key spec kind name flag=""
    key="$(basename "$script")"; key="${key#update-}"; key="${key%.sh}"
    spec="$(_brew_spec "$key")" || { log_warn "no Homebrew mapping for '$key' on macOS — skipping."; return 0; }
    kind="${spec%% *}"; name="${spec#* }"
    ensure_brew || { log_error "Homebrew is required on macOS."; return 1; }
    [ "$kind" = cask ] && flag="--cask"
    if [ "${1:-}" = remove ]; then
        log_clean "Removing $name (brew)..."
        brew uninstall $flag "$name" || log_warn "brew uninstall failed ($name may not be installed)."
        log_done "$key removed."
        return 0
    fi
    if brew list $flag "$name" >/dev/null 2>&1; then
        log_install "Upgrading $name via Homebrew..."
        brew upgrade $flag "$name" || true
    else
        log_install "Installing $name via Homebrew..."
        brew install $flag "$name"
    fi
    log_done "$key ready."
}

ensure_flatpak() {
    if ! command -v flatpak >/dev/null 2>&1; then
        log_install "Installing flatpak..."
        install_pkgs flatpak || return 1
    fi
    flatpak remote-add --user --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
}

install_flatpak() {
    local app="$1"
    ensure_flatpak || return 1
    log_install "Installing/updating $app from Flathub..."
    flatpak install --user -y --or-update flathub "$app"
}

remove_flatpak() { flatpak uninstall --user -y "$@"; }

secret_service_available() {
    command -v busctl >/dev/null 2>&1 || return 1
    busctl --user list --no-legend --no-pager 2>/dev/null \
        | awk '{ print $1 }' | grep -qx org.freedesktop.secrets
}
