#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

REPO="ryanoasis/nerd-fonts"
BASE="https://github.com/$REPO/releases/latest/download"
if [ "$OS" = darwin ]; then
    FONT_DIR="$HOME/Library/Fonts/NerdFonts"
else
    FONT_DIR="$HOME/.local/share/fonts/NerdFonts"
fi

FONTS=(
    Terminus
    Hack
    FiraCode
    ZedMono
    JetBrainsMono
    UbuntuMono
    ShareTechMono
    SourceCodePro
)

cleanup() {
    log_clean "Removing Nerd Fonts..."
    remove_paths "$FONT_DIR"
    remove_stamp nerd-fonts
    command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1 || true
    log_done "Nerd Fonts removed."
}
dispatch_remove "$@"

log_search "Fetching the latest Nerd Fonts version..."
LATEST=$(fetch "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name')
if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
    log_error "Could not determine the latest Nerd Fonts version."
    exit 1
fi
log_found "Latest version found: $LATEST"

font_installed() {
    find "$FONT_DIR/$1" -maxdepth 1 -type f \( -name '*.ttf' -o -name '*.otf' \) 2>/dev/null | grep -q .
}

INSTALLED=$(read_stamp "nerd-fonts")
if version_current "$INSTALLED" "$LATEST"; then
    all_present=1
    for font in "${FONTS[@]}"; do
        font_installed "$font" || { all_present=0; break; }
    done
    if [ "$all_present" -eq 1 ]; then
        log_done "Nerd Fonts $INSTALLED already installed — skipping. (set FORCE=1 to reinstall)"
        exit 0
    fi
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

ensure_dir "$FONT_DIR"

for font in "${FONTS[@]}"; do
    zip="$TMPDIR/$font.zip"
    log_download "Downloading $font Nerd Font..."
    if ! download "$BASE/$font.zip" "$zip"; then
        log_warn "Failed to download $font.zip; skipping."
        continue
    fi

    log_install "Installing $font to $FONT_DIR/$font..."
    rm -rf "${FONT_DIR:?}/$font"
    ensure_dir "$FONT_DIR/$font"
    unzip -j -o "$zip" '*.ttf' '*.otf' -d "$FONT_DIR/$font" >/dev/null 2>&1 || true
    font_installed "$font" || log_warn "No font files extracted from $font.zip."
done

log_warn "No per-asset checksums published by Nerd Fonts; skipping hash check."

if command -v fc-cache >/dev/null 2>&1; then
    log_install "Rebuilding font cache..."
    fc-cache -f "$FONT_DIR"
elif [ "$OS" = darwin ]; then
    log_info "macOS picks up fonts in ~/Library/Fonts automatically — no cache refresh needed."
else
    log_warn "fc-cache not found (install fontconfig); fonts copied but cache not refreshed."
fi

write_stamp "nerd-fonts" "$LATEST"

log_done "Nerd Fonts $LATEST installed."
