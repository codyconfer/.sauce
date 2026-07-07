#! /bin/bash
command -v log_error >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

DESKTOP_TEMPLATE="${DESKTOP_TEMPLATE:-$SAUCE_DIR/configs/applications/app.desktop.template}"

install_desktop_entry() {
    local id="${1:-}"
    if [ -z "$id" ]; then
        log_error "install_desktop_entry: missing entry id"
        return 1
    fi
    if [ ! -f "$DESKTOP_TEMPLATE" ]; then
        log_error "desktop template not found: $DESKTOP_TEMPLATE"
        return 1
    fi

    local name="${APP_NAME:-$id}"
    local exec_cmd="${APP_EXEC:-}"
    local icon="${APP_ICON:-}"
    local comment="${APP_COMMENT:-}"
    local categories="${APP_CATEGORIES:-}"

    if [ -z "$exec_cmd" ]; then
        log_error "install_desktop_entry: APP_EXEC is required for '$id'"
        return 1
    fi

    if [ -n "$icon" ] && [ -f "$icon" ]; then
        ensure_dir "$ICONS_DIR"
        local dest="$ICONS_DIR/$id.${icon##*.}"
        cp -f "$icon" "$dest"
        icon="$dest"
    fi

    local content
    content="$(cat "$DESKTOP_TEMPLATE")"
    content="${content//'${APP_NAME}'/$name}"
    content="${content//'${APP_COMMENT}'/$comment}"
    content="${content//'${APP_EXEC}'/$exec_cmd}"
    content="${content//'${APP_ICON}'/$icon}"
    content="${content//'${APP_CATEGORIES}'/$categories}"

    ensure_dir "$DESKTOP_DIR"
    local target="$DESKTOP_DIR/$id.desktop"
    if [ -f "$target" ] && [ "$(cat "$target")" = "$content" ]; then
        log_info "Desktop entry '$id' already up to date."
        return 0
    fi

    printf '%s\n' "$content" > "$target"
    chmod +x "$target"
    command -v update-desktop-database >/dev/null 2>&1 &&
        update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    log_link "Registered desktop entry '$id' -> $target"
}
