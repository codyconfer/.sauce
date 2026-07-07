#! /bin/bash
command -v log_error >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

_profile_upsert() {
    local store="$1" tool="$2" ext="$3" label="$4" content
    ensure_dir "$store"
    local frag="$store/${tool}.${ext}"
    content="$(cat)"
    if [ -f "$frag" ] && [ "$(cat "$frag")" = "$content" ]; then
        log_info "$label profile for '$tool' already up to date."
    else
        printf '%s\n' "$content" > "$frag"
        log_link "Registered $label profile for '$tool'."
    fi
}

profile_register() {
    local tool="${1:-}"
    if [ -z "$tool" ]; then
        log_error "profile_register: missing tool name"
        return 1
    fi
    _profile_upsert "$PROFILE_D/posix" "$tool" sh posix
}

profile_register_fish() {
    local tool="${1:-}"
    if [ -z "$tool" ]; then
        log_error "profile_register_fish: missing tool name"
        return 1
    fi
    _profile_upsert "$PROFILE_D/fish" "$tool" fish fish
}
