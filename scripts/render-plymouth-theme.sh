#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

SRC_DIR="$SCRIPT_DIR/../assets/plymouth/src"
THEMES_DIR="$SCRIPT_DIR/../assets/plymouth"
SCALE="${SCALE:-1}"
FRAMES="${FRAMES:-30}"

ALL_THEMES=(grafana arch)
TEXT="#ffffff"

theme_palette() {
    case "$1" in
        grafana)
            THEME_NAME=Grafana
            THEME_DESC="Grafana Labs splash with a graphical LUKS passphrase prompt"
            THEME_LOGO=grafana-logo.svg
            THEME_FONT="Inter"
            THEME_TITLE_FONT="Inter Light"
            BRAND_FROM="#F55F3E"
            BRAND_TO="#FF8833"
            SURFACE="#22252b"
            BORDER="#363940"
            BG_TOP=0x181b1f
            BG_BOTTOM=0x111217
            ;;
        arch)
            THEME_NAME="Arch Linux"
            THEME_DESC="Arch Linux splash with a graphical LUKS passphrase prompt"
            THEME_LOGO=arch-logo.svg
            THEME_FONT="Noto Sans"
            THEME_TITLE_FONT="Noto Sans Light"
            BRAND_FROM="#0f7ab5"
            BRAND_TO="#1793d1"
            SURFACE="#242424"
            BORDER="#3c3c3c"
            BG_TOP=0x1a1a1a
            BG_BOTTOM=0x0d0d0d
            ;;
        *)
            log_error "unknown theme: $1 (known: ${ALL_THEMES[*]})"
            return 1
            ;;
    esac
    THEME_OUT="$THEMES_DIR/$1"
}

px() { awk -v n="$1" -v s="$SCALE" 'BEGIN { printf "%d", n * s + 0.5 }'; }

require() {
    local missing=0 t
    for t in rsvg-convert magick; do
        command -v "$t" >/dev/null 2>&1 || { log_error "missing required tool: $t"; missing=1; }
    done
    [ "$missing" = 0 ] || { log_hint "install librsvg and imagemagick, then re-run."; return 1; }
}

render_watermark() {
    rsvg-convert -w "$(px 256)" "$SRC_DIR/$THEME_LOGO" -o "$THEME_OUT/watermark.png"
}

render_lock() {
    local s g
    s="$(px 34)"; g="$(px 24)"
    rsvg-convert -w "$g" -h "$g" "$SRC_DIR/lock.svg" \
        | magick png:- -fill "$BRAND_TO" -colorize 100 \
            -background none -gravity center -extent "${s}x${s}" "$THEME_OUT/lock.png"
}

render_entry() {
    local w h r sw
    w="$(px 305)"; h="$(px 34)"; r="$(px 2)"; sw="$(px 1)"
    rsvg-convert -w "$w" -h "$h" -o "$THEME_OUT/entry.png" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h" viewBox="0 0 $w $h">
  <rect x="$(awk -v s="$sw" 'BEGIN{print s/2}')" y="$(awk -v s="$sw" 'BEGIN{print s/2}')"
        width="$(awk -v w="$w" -v s="$sw" 'BEGIN{print w-s}')"
        height="$(awk -v h="$h" -v s="$sw" 'BEGIN{print h-s}')"
        rx="$r" ry="$r" fill="$SURFACE" stroke="$BORDER" stroke-width="$sw"/>
</svg>
SVG
}

render_bullet() {
    local s c r
    s="$(px 10)"
    c="$(awk -v s="$s" 'BEGIN{print s/2}')"
    r="$(awk -v s="$s" 'BEGIN{print s/2 - s*0.08}')"
    rsvg-convert -w "$s" -h "$s" -o "$THEME_OUT/bullet.png" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="$s" height="$s" viewBox="0 0 $s $s">
  <circle cx="$c" cy="$c" r="$r" fill="$TEXT" fill-opacity="0.87"/>
</svg>
SVG
}

render_throbber() {
    local s c r sw dash gap i angle name
    s="$(px 32)"
    c="$(awk -v s="$s" 'BEGIN{print s/2}')"
    r="$(awk -v s="$s" 'BEGIN{print s/2 - s*0.094}')"
    sw="$(awk -v s="$s" 'BEGIN{print s*0.094}')"
    dash="$(awk -v r="$r" 'BEGIN{print 2*3.14159265*r*0.62}')"
    gap="$(awk -v r="$r" 'BEGIN{print 2*3.14159265*r*0.38}')"

    rm -f "$THEME_OUT"/throbber-*.png
    for ((i = 1; i <= FRAMES; i++)); do
        angle="$(awk -v i="$i" -v n="$FRAMES" 'BEGIN{printf "%.3f", (i-1)*360/n}')"
        name="$(printf '%s/throbber-%04d.png' "$THEME_OUT" "$i")"
        rsvg-convert -w "$s" -h "$s" -o "$name" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="$s" height="$s" viewBox="0 0 $s $s">
  <defs>
    <linearGradient id="brand" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="$BRAND_FROM"/>
      <stop offset="1" stop-color="$BRAND_TO"/>
    </linearGradient>
  </defs>
  <circle cx="$c" cy="$c" r="$r" fill="none" stroke="$SURFACE" stroke-width="$sw" stroke-opacity="0.7"/>
  <g transform="rotate($angle $c $c)">
    <circle cx="$c" cy="$c" r="$r" fill="none" stroke="url(#brand)" stroke-width="$sw"
            stroke-linecap="round" stroke-dasharray="$dash $gap"/>
  </g>
</svg>
SVG
    done
}

write_theme_file() {
    local theme="$1" mode
    cat > "$THEME_OUT/$theme.plymouth" <<CONF
[Plymouth Theme]
Name=$THEME_NAME
Description=$THEME_DESC
ModuleName=two-step

[two-step]
Font=$THEME_FONT 12
TitleFont=$THEME_TITLE_FONT 28
ImageDir=/usr/share/plymouth/themes/$theme
WatermarkHorizontalAlignment=.5
WatermarkVerticalAlignment=.38
DialogHorizontalAlignment=.5
DialogVerticalAlignment=.58
TitleHorizontalAlignment=.5
TitleVerticalAlignment=.46
HorizontalAlignment=.5
VerticalAlignment=.78
Transition=none
TransitionDuration=0.0
BackgroundStartColor=$BG_TOP
BackgroundEndColor=$BG_BOTTOM
ProgressBarBackgroundColor=$(printf '0x%s' "${SURFACE#\#}")
ProgressBarForegroundColor=$(printf '0x%s' "${BRAND_TO#\#}")
MessageBelowAnimation=true

[boot-up]
UseEndAnimation=false

[shutdown]
UseEndAnimation=false

[reboot]
UseEndAnimation=false
CONF
    for mode in "updates:Installing Updates..." "system-upgrade:Upgrading System..." \
        "firmware-upgrade:Upgrading Firmware..." "system-reset:Resetting System..."; do
        cat >> "$THEME_OUT/$theme.plymouth" <<CONF

[${mode%%:*}]
SuppressMessages=true
ProgressBarShowPercentComplete=true
UseProgressBar=true
Title=${mode#*:}
SubTitle=Do not turn off your computer
CONF
    done
}

render_theme() {
    local theme="$1"
    theme_palette "$theme" || return 1
    [ -f "$SRC_DIR/$THEME_LOGO" ] || { log_error "missing $SRC_DIR/$THEME_LOGO"; return 1; }
    mkdir -p "$THEME_OUT"

    log_install "Rendering the $THEME_NAME Plymouth theme at scale $SCALE..."
    render_watermark
    render_lock
    render_entry
    render_bullet
    render_throbber
    write_theme_file "$theme"
    log_link "$theme: watermark $(identify -format '%wx%h' "$THEME_OUT/watermark.png"), throbber ${FRAMES}x$(identify -format '%wx%h' "$THEME_OUT/throbber-0001.png")"
}

require || exit 1
[ -d "$SRC_DIR" ] || { log_error "missing $SRC_DIR"; exit 1; }

declare -a targets=("$@")
[ "${#targets[@]}" -gt 0 ] || targets=("${ALL_THEMES[@]}")
for target in "${targets[@]}"; do
    render_theme "$target" || exit 1
done
log_done "Theme assets written to $THEMES_DIR"
