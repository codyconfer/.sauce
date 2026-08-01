#! /bin/bash

# Sway companion tools that have no Ubuntu/Debian packages — built from
# source (cargo/meson/make/go), fetched as scripts, or pulled from Flathub.
# Installed when 'sway' is selected in guiApps; safe to re-run (git-rev stamps).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [ "$OS" = darwin ]; then
    log_info "sway tools are Linux-only — skipping on macOS."
    exit 0
fi

SRC_CACHE="$CACHE/sway-tools"
FONT_DIR="$HOME/.local/share/fonts"
FA_VERSION="${FA_VERSION:-6.7.2}"

declare -a _FAILED=()
_step_failed() { _FAILED+=("$1"); log_warn "$1 failed — continuing."; }

cleanup() {
    log_clean "Removing sway companion tools..."
    remove_cmd wayshot sway-overfocus wl-clip-persist lumactl zofi \
        waylogout havoc exposway exposwayd way-displays swaycycle \
        sway-screenshot swaydim
    remove_paths "$SRC_CACHE" \
        "$FONT_DIR/FontAwesome6" "$FONT_DIR/NerdFontsSymbolsOnly"
    remove_stamp sway-overfocus wl-clip-persist lumactl zofi waylogout \
        havoc exposway way-displays swaycycle sway-screenshot swaydim \
        fontawesome6 nerd-symbols
    remove_flatpak io.github.seadve.Kooha || true
    command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1 || true
    log_done "sway tools removed."
    log_hint "apt packages (mpv, swayimg, wlsunset, ...) and build deps were left in place."
}
dispatch_remove "$@"

ensure_cargo() {
    [ -s "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
    command -v cargo >/dev/null 2>&1 && return 0
    log_install "cargo not found — installing the distro rust toolchain..."
    case "$(detect_family)" in
        arch) install_pkgs rust ;;
        *)    install_pkgs cargo ;;
    esac
    command -v cargo >/dev/null 2>&1 && return 0
    log_warn "cargo still not found — run 'bash ~/.sauce/scripts/update-rustup.sh' first."
    return 1
}

ensure_go() {
    command -v go >/dev/null 2>&1 || export PATH="$PATH:/usr/local/go/bin"
    command -v go >/dev/null 2>&1 && return 0
    log_install "go not found — installing the distro Go toolchain..."
    case "$(detect_family)" in
        debian) install_pkgs golang-go ;;
        *)      install_pkgs golang ;;
    esac
    command -v go >/dev/null 2>&1 && return 0
    log_warn "go still not found — run 'bash ~/.sauce/scripts/update-go.sh' first."
    return 1
}

# Latest commit on a repo's default branch; used as the version stamp for
# git-sourced tools so unchanged upstreams are skipped on re-runs.
git_head() { git ls-remote "$1" HEAD 2>/dev/null | awk '{print $1}' | head -c 12; }

# cargo_tool <name> <crate-or-git-url> [extra cargo args...]
# Installs into ~/.local/bin via --root ~/.local. Stamped by crates.io
# resolution (cargo skips same-version reinstalls) or git HEAD.
cargo_tool() {
    local name="$1" src="$2"; shift 2
    ensure_cargo || return 1
    local stamp="" installed=""
    if [[ "$src" == https://* ]]; then
        stamp="$(git_head "$src")"
        installed="$(read_stamp "$name")"
        if [ -n "$stamp" ] && version_current "$installed" "$stamp" && command -v "$name" >/dev/null 2>&1; then
            log_done "$name is already at upstream HEAD — skipping. (set FORCE=1 to rebuild)"
            return 0
        fi
        log_install "Building $name from $src (cargo)..."
        cargo install --locked ${FORCE:+--force} --git "$src" --root "$HOME/.local" "$@" || return 1
    else
        log_install "Installing $name from crates.io (cargo)..."
        cargo install --locked ${FORCE:+--force} "$src" --root "$HOME/.local" "$@" || return 1
    fi
    [ -n "$stamp" ] && write_stamp "$name" "$stamp"
    log_done "$name installed -> $BIN/$name"
}

# clone_at_stamp <name> <url> [ref] — clones (or refreshes) into $SRC_CACHE/<name>.
# Returns non-zero ONLY on clone failure. Sets CLONE_SKIP=1 (and returns 0) when
# the stamp says the installed build is already current. Sets CLONE_DIR/CLONE_REV.
clone_at_stamp() {
    local name="$1" url="$2" ref="${3:-}"
    CLONE_DIR="$SRC_CACHE/$name"
    CLONE_SKIP=""
    CLONE_REV="$(git_head "$url")"
    if [ -z "$ref" ] && [ -n "$CLONE_REV" ] \
        && version_current "$(read_stamp "$name")" "$CLONE_REV" \
        && command -v "$name" >/dev/null 2>&1; then
        log_done "$name is already at upstream HEAD — skipping. (set FORCE=1 to rebuild)"
        CLONE_SKIP=1
        return 0
    fi
    if [ -n "$ref" ] && command -v "$name" >/dev/null 2>&1 \
        && version_gate "$name" "$(read_stamp "$name")" "$ref"; then
        CLONE_SKIP=1
        return 0
    fi
    rm -rf "$CLONE_DIR"
    ensure_dir "$SRC_CACHE"
    log_download "Cloning $url${ref:+ ($ref)}..."
    git clone --depth 1 ${ref:+--branch "$ref"} "$url" "$CLONE_DIR" || return 1
    [ -n "$ref" ] && CLONE_REV="$ref"
    return 0
}

build_deps() {
    log_install "Installing build dependencies..."
    case "$(detect_family)" in
        debian)
            install_pkgs meson ninja-build pkg-config cmake \
                libwayland-dev wayland-protocols libxkbcommon-dev \
                libcairo2-dev libgdk-pixbuf-2.0-dev scdoc \
                libpango1.0-dev libjson-c-dev libgbm-dev \
                libyaml-cpp-dev libinput-dev libudev-dev \
                || log_warn "some build deps failed to install."
            # zofi (GPUI) — dep list from the project's own ubuntu CI
            install_pkgs libxkbcommon-x11-dev libvulkan-dev libfontconfig1-dev \
                libfreetype-dev libgtk-4-dev libasound2-dev libssl-dev \
                libx11-xcb-dev libxcb1-dev libxcb-composite0-dev libxcb-xfixes0-dev \
                libxcb-xinput-dev libxcb-render0-dev libxcb-shape0-dev libxcb-dri3-dev \
                libxcb-present-dev libxcb-sync-dev libxcb-randr0-dev libxcb-shm0-dev \
                libxcb-xkb-dev libxcb-dpms0-dev libxcb-cursor-dev libxcb-icccm4-dev \
                libxcb-res0-dev \
                || log_warn "some zofi build deps failed to install." ;;
        fedora)
            install_pkgs meson ninja-build pkgconf-pkg-config cmake \
                wayland-devel wayland-protocols-devel libxkbcommon-devel \
                cairo-devel gdk-pixbuf2-devel scdoc pango-devel json-c-devel \
                yaml-cpp-devel libinput-devel systemd-devel mesa-libgbm-devel \
                || log_warn "some build deps failed to install." ;;
        arch)
            install_pkgs meson ninja pkgconf cmake \
                wayland wayland-protocols libxkbcommon cairo gdk-pixbuf2 scdoc \
                pango json-c yaml-cpp libinput mesa \
                || log_warn "some build deps failed to install." ;;
    esac
}

install_wayshot()         { cargo_tool wayshot wayshot; }
install_sway_overfocus()  { cargo_tool sway-overfocus https://github.com/korreman/sway-overfocus; }
install_wl_clip_persist() { cargo_tool wl-clip-persist https://github.com/Linus789/wl-clip-persist; }
install_lumactl()         { cargo_tool lumactl https://github.com/danyspin97/lumactl; }
install_zofi()            { cargo_tool zofi https://github.com/emskin/zskins zofi; }

install_waylogout() {
    clone_at_stamp waylogout https://github.com/loserMcloser/waylogout || return 1
    [ -n "$CLONE_SKIP" ] && return 0
    log_install "Building waylogout (meson)..."
    ( cd "$CLONE_DIR" \
        && meson setup build --prefix="$HOME/.local" \
            -Dbash-completions=false -Dfish-completions=false >/dev/null \
        && ninja -C build >/dev/null \
        && ninja -C build install >/dev/null ) || return 1
    write_stamp waylogout "$CLONE_REV"
    log_done "waylogout installed -> $BIN/waylogout"
}

install_havoc() {
    clone_at_stamp havoc https://github.com/ii8/havoc || return 1
    [ -n "$CLONE_SKIP" ] && return 0
    log_install "Building havoc (make)..."
    ( cd "$CLONE_DIR" \
        && make CFLAGS="-O2 -DNDEBUG" >/dev/null \
        && make install PREFIX="$HOME/.local" >/dev/null ) || return 1
    write_stamp havoc "$CLONE_REV"
    log_done "havoc installed -> $BIN/havoc"
}

install_exposway() {
    clone_at_stamp exposway https://github.com/RadioNoiseE/exposway || return 1
    [ -n "$CLONE_SKIP" ] && return 0
    log_install "Building exposway (make)..."
    ( cd "$CLONE_DIR" \
        && make CC=gcc >/dev/null \
        && make CC=gcc PREFIX="$HOME/.local" install >/dev/null ) || return 1
    ensure_dir "$HOME/.local/state/exposway"
    write_stamp exposway "$CLONE_REV"
    log_done "exposway installed -> $BIN/exposway (+ exposwayd)"
}

WAY_DISPLAYS_VERSION="${WAY_DISPLAYS_VERSION:-1.15.0}"
install_way_displays() {
    clone_at_stamp way-displays https://github.com/alex-courtis/way-displays "$WAY_DISPLAYS_VERSION" || return 1
    [ -n "$CLONE_SKIP" ] && return 0
    log_install "Building way-displays $WAY_DISPLAYS_VERSION (make)..."
    ( cd "$CLONE_DIR" && make -j"$(nproc 2>/dev/null || echo 2)" >/dev/null ) || return 1
    install -Dm755 "$CLONE_DIR/way-displays" "$BIN/way-displays" || return 1
    write_stamp way-displays "$WAY_DISPLAYS_VERSION"
    log_done "way-displays installed -> $BIN/way-displays"
}

install_swaycycle() {
    # go install is broken upstream (go.mod module path is bare 'swaycycle')
    clone_at_stamp swaycycle https://codeberg.org/scip/swaycycle.git || return 1
    [ -n "$CLONE_SKIP" ] && return 0
    ensure_go || return 1
    log_install "Building swaycycle (go)..."
    ( cd "$CLONE_DIR" && go build -o "$BIN/swaycycle" . ) || return 1
    write_stamp swaycycle "$CLONE_REV"
    log_done "swaycycle installed -> $BIN/swaycycle"
}

# fetch_script <name> <raw-url> — single-file tools that live at ~/.local/bin
fetch_script() {
    local name="$1" url="$2"
    ensure_dir "$BIN"
    log_download "Fetching $name..."
    download "$url" "$BIN/$name.tmp" || { rm -f "$BIN/$name.tmp"; return 1; }
    chmod +x "$BIN/$name.tmp"
    mv -f "$BIN/$name.tmp" "$BIN/$name"
    log_done "$name installed -> $BIN/$name"
}

install_sway_screenshot() {
    fetch_script sway-screenshot \
        https://raw.githubusercontent.com/Gustash/sway-screenshot/main/sway-screenshot
}

install_swaydim() {
    fetch_script swaydim \
        https://codeberg.org/achill/swaydim/raw/branch/main/swaydim.py
}

install_fonts() {
    # Font Awesome 6 Free — waybar icons, waylogout symbols, sway title icons.
    # (Ubuntu's fonts-font-awesome is 4.7 and lacks the FA6 glyphs.)
    if ! version_gate "Font Awesome" "$(read_stamp fontawesome6)" "$FA_VERSION"; then
        local zip="$SRC_CACHE/fontawesome.zip"
        ensure_dir "$SRC_CACHE"
        log_download "Downloading Font Awesome $FA_VERSION Free (desktop)..."
        if download "https://use.fontawesome.com/releases/v$FA_VERSION/fontawesome-free-$FA_VERSION-desktop.zip" "$zip"; then
            rm -rf "$FONT_DIR/FontAwesome6"
            ensure_dir "$FONT_DIR/FontAwesome6"
            unzip -joq "$zip" "*/otfs/*.otf" -d "$FONT_DIR/FontAwesome6" \
                && write_stamp fontawesome6 "$FA_VERSION" \
                && log_done "Font Awesome $FA_VERSION installed." \
                || _step_failed "fontawesome-extract"
            rm -f "$zip"
        else
            _step_failed "fontawesome-download"
        fi
    fi

    # Nerd Fonts Symbols Only — icon fallback for waybar/sway titles.
    local nf_latest
    nf_latest=$(fetch "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" | jq -r '.tag_name')
    if [ -n "$nf_latest" ] && [ "$nf_latest" != null ] \
        && ! version_gate "Nerd Fonts Symbols" "$(read_stamp nerd-symbols)" "$nf_latest"; then
        local tarball="$SRC_CACHE/NerdFontsSymbolsOnly.tar.xz"
        ensure_dir "$SRC_CACHE"
        log_download "Downloading Nerd Fonts Symbols Only $nf_latest..."
        if download "https://github.com/ryanoasis/nerd-fonts/releases/download/$nf_latest/NerdFontsSymbolsOnly.tar.xz" "$tarball"; then
            rm -rf "$FONT_DIR/NerdFontsSymbolsOnly"
            ensure_dir "$FONT_DIR/NerdFontsSymbolsOnly"
            tar -xJf "$tarball" -C "$FONT_DIR/NerdFontsSymbolsOnly" \
                && write_stamp nerd-symbols "$nf_latest" \
                && log_done "Nerd Fonts Symbols Only $nf_latest installed." \
                || _step_failed "nerd-symbols-extract"
            rm -f "$tarball"
        else
            _step_failed "nerd-symbols-download"
        fi
    fi
    command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1 || true
}

install_kooha() {
    install_flatpak io.github.seadve.Kooha
}

set_mime_defaults() {
    command -v xdg-mime >/dev/null 2>&1 || { log_info "xdg-mime not available — skipping mime defaults."; return 0; }
    log_install "Setting default applications (swayimg for images, mpv for media)..."
    xdg-mime default swayimg.desktop \
        image/jpeg image/png image/gif image/webp image/svg+xml image/bmp \
        image/tiff image/avif image/heif 2>/dev/null || log_warn "swayimg mime defaults failed."
    xdg-mime default mpv.desktop \
        video/mp4 video/x-matroska video/webm video/mpeg video/quicktime \
        video/x-msvideo video/ogg audio/mpeg audio/flac audio/x-wav audio/ogg \
        audio/mp4 2>/dev/null || log_warn "mpv mime defaults failed."
}

setup_i2c() {
    # lumactl talks DDC to external monitors over /dev/i2c-*; the ddcutil
    # package (installed with the sway apt set) ships the udev rules.
    [ -e /etc/modules-load.d/i2c-dev.conf ] && return 0
    log_install "Enabling the i2c-dev kernel module for external-monitor brightness (lumactl)..."
    echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null \
        && sudo modprobe i2c-dev 2>/dev/null \
        || log_warn "could not enable i2c-dev; external-monitor brightness may not work."
    log_hint "If lumactl can't reach external displays, check 'ddcutil detect' and i2c permissions."
}

build_deps || log_warn "build-dep install had failures; some builds may not compile."

install_wayshot          || _step_failed wayshot
install_sway_overfocus   || _step_failed sway-overfocus
install_wl_clip_persist  || _step_failed wl-clip-persist
install_lumactl          || _step_failed lumactl
install_zofi             || _step_failed zofi
install_waylogout        || _step_failed waylogout
install_havoc            || _step_failed havoc
install_exposway         || _step_failed exposway
install_way_displays     || _step_failed way-displays
install_swaycycle        || _step_failed swaycycle
install_sway_screenshot  || _step_failed sway-screenshot
install_swaydim          || _step_failed swaydim
install_fonts
install_kooha            || _step_failed kooha
set_mime_defaults        || true
setup_i2c                || true

if [ "${#_FAILED[@]}" -gt 0 ]; then
    log_error "sway tools with failures: ${_FAILED[*]}"
    log_hint "Re-run 'bash ~/.sauce/scripts/update-sway-tools.sh' (FORCE=1 to rebuild)."
    exit 1
fi
log_done "All sway companion tools are installed and current."
