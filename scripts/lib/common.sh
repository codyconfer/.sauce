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

fetch()                 { curl -fsSL "$1"; }
download()              { curl -fL --output "$2" "$1"; }
download_with_headers() { curl -fL -D "$3" --output "$2" "$1"; }

verify_sha256() {
    log_verify "Verifying checksum..."
    echo "$1  $2" | sha256sum -c -
}

verify_md5_etag() {
    local etag
    etag=$(grep -i '^etag:' "$1" | tail -n1 | tr -d ' \r"' | sed 's/^[Ee][Tt][Aa][Gg]://' || true)
    if [[ "$etag" =~ ^[0-9a-f]{32}$ ]]; then
        log_verify "Verifying MD5 against server ETag..."
        echo "$etag  $2" | md5sum -c -
    else
        log_warn "No usable checksum from server (ETag='$etag'); skipping hash check."
    fi
}

version_current() {
    local installed="$1" latest="$2"
    [ -n "${FORCE:-}" ] && return 1
    if [ -z "$installed" ] || [ -z "$latest" ]; then return 1; fi
    [ "${installed#v}" = "${latest#v}" ]
}

version_gate() {
    if version_current "$2" "$3"; then
        log_done "$1 $2 is already the latest — skipping. (set FORCE=1 to reinstall)"
        return 0
    fi
    return 1
}

VERSIONS_DIR="${VERSIONS_DIR:-$APPS/.versions}"
read_stamp()  { cat "$VERSIONS_DIR/$1" 2>/dev/null || true; }
write_stamp() { ensure_dir "$VERSIONS_DIR"; printf '%s\n' "$2" > "$VERSIONS_DIR/$1"; }

source "$(dirname "${BASH_SOURCE[0]}")/distro.sh"
source "$(dirname "${BASH_SOURCE[0]}")/profile.sh"
source "$(dirname "${BASH_SOURCE[0]}")/desktop.sh"
source "$(dirname "${BASH_SOURCE[0]}")/stow.sh"
