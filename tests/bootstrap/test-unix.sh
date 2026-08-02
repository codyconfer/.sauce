#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 SOURCE_DIR EXPECTED_FAMILY" >&2
    exit 2
fi

SOURCE_DIR="$(cd "$1" && pwd)"
EXPECTED_FAMILY="$2"
TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

mkdir -p "$TEST_HOME/.sauce"
cp -a "$SOURCE_DIR/." "$TEST_HOME/.sauce/"

export HOME="$TEST_HOME"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export SAUCE_DIR="$HOME/.sauce"
export BIN_DIR="$HOME/.local/bin"
export SAUCE_HEADLESS=false
export SAUCE_EMULATORS="steam wine qemu"
export SAUCE_GUI_APPS="firefox sway alacritty gnuradio qdmr vscode zed claude codex cursor docker ghidra jetbrains-toolbox lmstudio obsidian bitwarden 1password"
export SAUCE_FLATPAKS="slack discord signal easyeffects obs-studio zen lutris retroarch zoom chirp sonic-pi"
export SAUCE_TOOLS="1password-cli aws azure-cli bitwarden-cli cloudflared gcloud gcx wrangler adb claude-code dotnet go k9s kubectl loglit nvim nvm ollama opencode pi poetry pyenv rustup tmux yarn"
export SAUCE_NET_TOOLS=true
export SAUCE_TAILSCALE=true

for file in "$SAUCE_DIR"/bootstrap.sh "$SAUCE_DIR"/scripts/*.sh \
    "$SAUCE_DIR"/scripts/lib/*.sh "$SAUCE_DIR"/home/.chezmoiscripts/*.sh; do
    bash -n "$file"
done
bash -n "$SAUCE_DIR/home/dot_bashrc"

BOOTSTRAP_LOG="$TEST_HOME/bootstrap.log"
if ! bash "$SAUCE_DIR/bootstrap.sh" --dry-run >"$BOOTSTRAP_LOG" 2>&1; then
    cat "$BOOTSTRAP_LOG" >&2
    exit 1
fi

CHEZMOI="$BIN_DIR/chezmoi"
if [ ! -x "$CHEZMOI" ]; then
    CHEZMOI="$(command -v chezmoi)"
fi

DATA="$($CHEZMOI data --source="$SAUCE_DIR" --format=json)"
grep -Fq "\"family\": \"$EXPECTED_FAMILY\"" <<<"$DATA"
grep -Fq '"headless": false' <<<"$DATA"
grep -Fq '"tailscale": true' <<<"$DATA"
for template in "$SAUCE_DIR"/home/.chezmoiscripts/*.sh.tmpl; do
    "$CHEZMOI" execute-template --source="$SAUCE_DIR" <"$template" | bash -n
done

grep -Fq 'uwsm start -N Plasma -D KDE -e -- startplasma-wayland' "$SAUCE_DIR/scripts/setup.sh"
grep -Fq '"Plasma (UWSM)"' "$SAUCE_DIR/scripts/setup.sh"
grep -Fq 'uwsm start -N Sway -D sway -e -- sway' "$SAUCE_DIR/scripts/setup.sh"
grep -Fq 'fairyglade/ly' "$SAUCE_DIR/scripts/setup.sh"
grep -Fq 'ly_set waylandsessions "$LY_SESSIONS"' "$SAUCE_DIR/scripts/setup.sh"
! grep -Fq 'lemurs' "$SAUCE_DIR/home/dot_config/sway/config"
! grep -Fq 'greetd/config.toml >/dev/null' "$SAUCE_DIR/scripts/setup.sh"

grep -Fq 'setup.sh" portals' "$SAUCE_DIR/home/.chezmoiscripts/run_once_after_76-portals.sh.tmpl"
grep -Fq 'portals)       setup_portals ;;' "$SAUCE_DIR/scripts/setup.sh"
grep -Fxq 'default=wlr' "$SAUCE_DIR/home/dot_config/xdg-desktop-portal/sway-portals.conf"
! grep -Fq 'gtk' "$SAUCE_DIR/home/dot_config/xdg-desktop-portal/sway-portals.conf"
grep -Fq 'default=gtk;kde' "$SAUCE_DIR/home/dot_config/xdg-desktop-portal/kde-portals.conf"
jq -e '.portals.sway == ["xdg-desktop-portal", "xdg-desktop-portal-wlr"]' \
    <<<"$DATA" >/dev/null

ALL_SELECTIONS="$SAUCE_EMULATORS $SAUCE_GUI_APPS $SAUCE_FLATPAKS $SAUCE_TOOLS"
for selection in $ALL_SELECTIONS; do
    grep -Fq "\"$selection\"" <<<"$DATA"
done

echo "Full $EXPECTED_FAMILY bootstrap dry run passed."
