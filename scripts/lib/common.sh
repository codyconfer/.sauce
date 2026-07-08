#! /bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

log_search()   { echo "🔍 $*"; }
log_found()    { echo "🚀 $*"; }
log_download() { echo "📥 $*"; }
log_verify()   { echo "🔐 $*"; }
log_install()  { echo "📦 $*"; }
log_clean()    { echo "🗑️ $*"; }
log_link()     { echo "🔗 $*"; }
log_info()     { echo "ℹ️  $*"; }
log_hint()     { echo "💡 $*"; }
log_warn()     { echo "⚠️  $*" >&2; }
log_error()    { echo "❌ Error: $*" >&2; }
log_done()     { echo "✅ ${*:-Installation complete!}"; }

ensure_dir() { mkdir -p "$1"; }

ensure_node() {
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        unset npm_config_prefix 2>/dev/null || true
        \. "$NVM_DIR/nvm.sh" || true
    fi
    command -v npm >/dev/null 2>&1
}

fetch()                 { curl -fsSL "$1"; }                       # URL -> stdout
download()              { curl -fL --output "$2" "$1"; }           # URL, dest
download_with_headers() { curl -fL -D "$3" --output "$2" "$1"; }   # URL, dest, headers-file

verify_sha256() {
    log_verify "Verifying checksum..."
    if command -v sha256sum >/dev/null 2>&1; then
        echo "$1  $2" | sha256sum -c -
    else
        echo "$1  $2" | shasum -a 256 -c -
    fi
}

verify_md5_etag() {
    local etag actual
    etag=$(grep -i '^etag:' "$1" | tail -n1 | tr -d ' \r"' | sed 's/^[Ee][Tt][Aa][Gg]://' || true)
    if [[ "$etag" =~ ^[0-9a-f]{32}$ ]]; then
        log_verify "Verifying MD5 against server ETag..."
        if command -v md5sum >/dev/null 2>&1; then
            echo "$etag  $2" | md5sum -c -
        elif command -v md5 >/dev/null 2>&1; then
            actual=$(md5 -q "$2")
            [ "$actual" = "$etag" ] && log_done "$2: OK" || { log_error "$2: FAILED MD5 check"; return 1; }
        else
            log_warn "No md5 tool available; skipping hash check."
        fi
    else
        log_warn "No usable checksum from server (ETag='$etag'); skipping hash check."
    fi
}

# extract_appimage_icon <appimage> <dest.png>
# Pull the app's icon (.DirIcon) out of an AppImage into <dest> without unpacking the
# whole (possibly gigabyte-sized) image. Best-effort: warns and returns non-zero if no
# icon is found — callers should treat it as optional (append `|| true`).
extract_appimage_icon() {
    local appimage="$1" dest="$2"
    local workdir root src target
    workdir=$(mktemp -d)
    root="$workdir/squashfs-root"

    # .DirIcon is the canonical app icon: usually a symlink to the real PNG. Extract the
    # pointer first, then the single file it references (extracting an exact path pulls
    # only that file, not the entire squashfs).
    if ! ( cd "$workdir" && "$appimage" --appimage-extract '.DirIcon' >/dev/null 2>&1 ); then
        log_warn "Could not read icon from $(basename "$appimage")."
        rm -rf "$workdir"
        return 1
    fi
    if [ -L "$root/.DirIcon" ]; then
        target=$(readlink "$root/.DirIcon")
        ( cd "$workdir" && "$appimage" --appimage-extract "$target" >/dev/null 2>&1 ) || true
        src="$root/$target"
    else
        src="$root/.DirIcon"
    fi

    if [ ! -f "$src" ]; then
        log_warn "No icon found inside $(basename "$appimage")."
        rm -rf "$workdir"
        return 1
    fi
    ensure_dir "$(dirname "$dest")"
    cp -f "$src" "$dest"
    rm -rf "$workdir"
    log_link "Extracted icon -> $dest"
}

# --- version gating ---------------------------------------------------------
# version_current <installed> <latest> -> 0 if same (ignoring a leading "v").
# Empty installed/latest, or FORCE set, => 1 ("not current, proceed").
version_current() {
    local installed="$1" latest="$2"
    [ -n "${FORCE:-}" ] && return 1
    if [ -z "$installed" ] || [ -z "$latest" ]; then return 1; fi
    [ "${installed#v}" = "${latest#v}" ]
}

# version_gate <label> <installed> <latest> -> logs + returns 0 when up to date.
# Intended use:  version_gate "Go" "$INSTALLED" "$LATEST" && exit 0
version_gate() {
    if version_current "$2" "$3"; then
        log_done "$1 $2 is already the latest — skipping. (set FORCE=1 to reinstall)"
        return 0
    fi
    return 1
}

# Stamp store for tools that can't report their own version (e.g. AppImages).
VERSIONS_DIR="${VERSIONS_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/sauce/versions}"
read_stamp()  { cat "$VERSIONS_DIR/$1" 2>/dev/null || true; }
write_stamp() { ensure_dir "$VERSIONS_DIR"; printf '%s\n' "$2" > "$VERSIONS_DIR/$1"; }

remove_paths() {
    local p
    for p in "$@"; do
        [ -n "$p" ] || continue
        if [ -e "$p" ] || [ -L "$p" ]; then
            log_clean "Removing $p"
            rm -rf "$p"
        fi
    done
}

remove_sudo_paths() {
    local p
    for p in "$@"; do
        [ -n "$p" ] || continue
        if [ -e "$p" ] || [ -L "$p" ]; then
            log_clean "Removing $p (sudo)"
            sudo rm -rf "$p"
        fi
    done
}

remove_cmd() {
    local c path
    for c in "$@"; do
        path="$(command -v "$c" 2>/dev/null || true)"
        [ -n "$path" ] && remove_paths "$path"
    done
}

remove_stamp() { local n; for n in "$@"; do rm -f "$VERSIONS_DIR/$n"; done; }

dispatch_remove() {
    if [ "${1:-}" = "remove" ]; then
        cleanup
        exit 0
    fi
}

source "$(dirname "${BASH_SOURCE[0]}")/distro.sh"
