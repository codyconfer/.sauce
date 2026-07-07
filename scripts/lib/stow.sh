#! /bin/bash
command -v log_error >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

_stow_ensure_installed() {
    command -v stow >/dev/null 2>&1 && return 0
    log_install "Installing GNU stow..."
    install_pkgs stow
}

_stow_backup_conflicts() {
    local pkg="$1" pkgdir="$STOW_DIR/$1"
    [ -d "$pkgdir" ] || return 0
    local stamp entry rel target dest resolved
    stamp="$(date +%Y%m%d%H%M%S)"
    while IFS= read -r -d '' entry; do
        rel="${entry#"$pkgdir"/}"
        target="$HOME/$rel"
        [ -e "$target" ] || [ -L "$target" ] || continue
        resolved="$(readlink -f "$target" 2>/dev/null || true)"
        case "$resolved" in "$STOW_DIR"/*) continue ;; esac
        if [ -L "$target" ]; then
            dest="$(readlink "$target" 2>/dev/null || true)"
            case "$dest" in "$STOW_DIR"/*) continue ;; esac
            log_warn "Removing non-stow symlink $target -> $dest"
            rm -f "$target"
        elif [ -f "$target" ] && [ -f "$entry" ]; then
            log_warn "Backing up existing $target -> $target.$stamp.bak"
            rm -rf "$target.$stamp.bak"
            mv "$target" "$target.$stamp.bak"
        fi
    done < <(find "$pkgdir" -mindepth 1 \( -type f -o -type d \) -print0)
}

_stow_salvage_user_region() {
    ensure_dir "$SAUCE_USER_DIR"
    local open='# >>> sauce:user >>>' close='# <<< sauce:user <<<' cand src
    _stow_extract() {
        awk -v o="$1" -v c="$2" '$0==o{f=1;next} $0==c{f=0;next} f' "$3"
    }
    if [ ! -f "$SAUCE_USER_DIR/user.sh" ]; then
        src=""
        for cand in "$HOME/.zshrc" "$HOME/.bashrc"; do
            if [ -f "$cand" ] && [ ! -L "$cand" ] && grep -qF "$open" "$cand"; then
                src="$cand"; break
            fi
        done
        if [ -n "$src" ]; then
            _stow_extract "$open" "$close" "$src" > "$SAUCE_USER_DIR/user.sh"
            log_link "Salvaged personal shell tweaks from $src -> $SAUCE_USER_DIR/user.sh"
        fi
    fi
    cand="$HOME/.config/fish/config.fish"
    if [ ! -f "$SAUCE_USER_DIR/user.fish" ] && [ -f "$cand" ] && [ ! -L "$cand" ] \
        && grep -qF "$open" "$cand"; then
        _stow_extract "$open" "$close" "$cand" > "$SAUCE_USER_DIR/user.fish"
        log_link "Salvaged personal fish tweaks from $cand -> $SAUCE_USER_DIR/user.fish"
    fi
}

stow_pkg() {
    local pkg="${1:-}"; shift || true
    [ -n "$pkg" ] || { log_error "stow_pkg: missing package name"; return 1; }
    _stow_ensure_installed || return 1
    _stow_backup_conflicts "$pkg"
    stow --dir "$STOW_DIR" --target "$HOME" --restow "$@" "$pkg" \
        && log_link "Stowed '$pkg'."
}

unstow_pkg() {
    local pkg="${1:-}"
    [ -n "$pkg" ] || { log_error "unstow_pkg: missing package name"; return 1; }
    _stow_ensure_installed || return 1
    stow --dir "$STOW_DIR" --target "$HOME" -D "$pkg" \
        && log_clean "Unstowed '$pkg'."
}

stow_all() {
    ensure_dir "$PROFILE_D/posix"
    ensure_dir "$PROFILE_D/fish"
    ensure_dir "$ZSH_PLUGINS"
    ensure_dir "$SAUCE_USER_DIR"
    _stow_salvage_user_region
    local pkg
    for pkg in "${SAUCE_STOW_PACKAGES[@]}"; do
        case "$pkg" in
            fish|zsh-plugins) stow_pkg "$pkg" --no-folding ;;
            *)                stow_pkg "$pkg" ;;
        esac
    done
    log_done "Stowed shell, prompt, and plugin configs."
}
