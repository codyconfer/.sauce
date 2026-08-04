#!/usr/bin/env bash
set -euo pipefail

SAUCE_DIR="${SAUCE_DIR:-$HOME/.sauce}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
DRY_RUN=false

case "${1:-}" in
    "") ;;
    --dry-run) DRY_RUN=true ;;
    *) echo "Usage: $0 [--dry-run]" >&2; exit 2 ;;
esac

log()  { echo "▶️  $*"; }
warn() { echo "⚠️  $*" >&2; }

PATH="$BIN_DIR:$PATH"

source_dotenv() {
    [ -f "$SAUCE_DIR/.env" ] || return 0
    set -a
    # shellcheck disable=SC1091
    . "$SAUCE_DIR/.env"
    set +a
}

op_requested() { [ -n "${OP_ACCOUNT:-}${OP_SERVICE_ACCOUNT_TOKEN:-}${OP_CONNECT_HOST:-}" ]; }
bw_requested() { [ -n "${BW_ENABLE:-}${BW_SERVER:-}${BW_CLIENTID:-}${BW_SESSION:-}${BW_PASSWORD:-}" ]; }

ensure_cli() {
    local cmd="$1" script="$2"
    command -v "$cmd" >/dev/null 2>&1 && return 0
    if [ "$DRY_RUN" = true ]; then
        log "Would install $cmd via scripts/$script."
        return 1
    fi
    log "Installing $cmd..."
    bash "$SAUCE_DIR/scripts/$script" || { warn "$cmd install failed; skipping its sign-in."; return 1; }
    command -v "$cmd" >/dev/null 2>&1
}

op_login() {
    op_requested || return 0
    ensure_cli op update-1password-cli.sh || return 0
    if op whoami >/dev/null 2>&1; then
        log "1Password CLI already authenticated."
        return 0
    fi
    if [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}${OP_CONNECT_HOST:-}" ]; then
        warn "1Password token/Connect variables are set but 'op whoami' failed; check those credentials."
        return 0
    fi
    if [ "$DRY_RUN" = true ]; then
        log "Would sign in to 1Password (account $OP_ACCOUNT)."
        return 0
    fi
    if [ ! -t 0 ]; then
        log "1Password needs an interactive sign-in; run 'op signin --account $OP_ACCOUNT' later."
        return 0
    fi
    if ! op account list >/dev/null 2>&1; then
        warn "'op account list' failed. Using the desktop app? Enable Settings > Developer > 'Integrate with 1Password CLI', then re-run."
        return 0
    fi
    if ! op account list 2>/dev/null | grep -Fq "$OP_ACCOUNT"; then
        log "Adding the 1Password account $OP_ACCOUNT..."
        op account add --address "$OP_ACCOUNT" || { warn "'op account add' failed."; return 0; }
    fi
    log "Signing in to 1Password ($OP_ACCOUNT)..."
    eval "$(op signin --account "$OP_ACCOUNT" 2>/dev/null || true)" || true
    if op whoami >/dev/null 2>&1; then
        log "1Password ready."
    else
        warn "1Password sign-in did not complete; 'op read' lookups in .env will be empty."
    fi
}

bw_login() {
    bw_requested || return 0
    ensure_cli bw update-bitwarden-cli.sh || return 0
    if [ -n "${BW_SERVER:-}" ] && [ "$DRY_RUN" = false ]; then
        local current
        current="$(bw status 2>/dev/null | grep -o '"serverUrl":"[^"]*"' | cut -d'"' -f4)"
        if [ "$current" != "$BW_SERVER" ]; then
            log "Pointing bw at $BW_SERVER..."
            bw config server "$BW_SERVER" >/dev/null 2>&1 \
                || warn "'bw config server' failed; log out of the current vault before changing servers."
        fi
    fi

    local status
    status="$(bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)"
    if [ "$status" = unlocked ]; then
        log "Bitwarden CLI already unlocked."
        return 0
    fi
    if [ "$DRY_RUN" = true ]; then
        log "Would log in / unlock Bitwarden (status: ${status:-unknown})."
        return 0
    fi

    if [ "$status" = unauthenticated ]; then
        if [ -n "${BW_CLIENTID:-}" ] && [ -n "${BW_CLIENTSECRET:-}" ]; then
            log "Logging in to Bitwarden with the API key..."
            bw login --apikey || { warn "'bw login --apikey' failed."; return 0; }
        elif [ -t 0 ]; then
            log "Logging in to Bitwarden..."
            bw login || { warn "'bw login' failed."; return 0; }
        else
            log "Bitwarden needs an interactive login; run 'bw login' later."
            return 0
        fi
    fi

    local session=""
    if [ -n "${BW_PASSWORD:-}" ]; then
        session="$(bw unlock --passwordenv BW_PASSWORD --raw 2>/dev/null || true)"
    elif [ -t 0 ]; then
        session="$(bw unlock --raw || true)"
    fi
    if [ -n "$session" ]; then
        export BW_SESSION="$session"
        log "Bitwarden unlocked; BW_SESSION exported for this run."
    else
        warn "Bitwarden is still locked; export BW_SESSION=\$(bw unlock --raw) before secret lookups."
    fi
}

install_prereqs() {
    local as_root=""
    if [ "$(id -u)" -ne 0 ]; then
        command -v sudo >/dev/null 2>&1 || return 1
        as_root=sudo
    fi
    if command -v apt-get >/dev/null 2>&1; then
        $as_root apt-get update && $as_root apt-get install -y "$@"
    elif command -v dnf >/dev/null 2>&1; then
        $as_root dnf install -y "$@"
    elif command -v pacman >/dev/null 2>&1; then
        $as_root pacman -Sy --needed --noconfirm "$@"
    else
        return 1
    fi
}

MISSING=()
command -v git >/dev/null 2>&1 || MISSING+=(git)
if [ "$(id -u)" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
    MISSING+=(sudo)
fi
if [ "${#MISSING[@]}" -gt 0 ]; then
    if [ "$DRY_RUN" = true ]; then
        log "Missing prerequisites (${MISSING[*]}); a real run would install them."
    else
        log "Installing prerequisites: ${MISSING[*]}..."
        if ! install_prereqs "${MISSING[@]}"; then
            echo "❌ Error: install these as root, then re-run: ${MISSING[*]}" >&2
            exit 1
        fi
    fi
fi

if command -v chezmoi >/dev/null 2>&1; then
    CHEZMOI="$(command -v chezmoi)"
else
    log "Installing chezmoi to $BIN_DIR..."
    mkdir -p "$BIN_DIR"
    sh -c "$(curl -fsSL https://get.chezmoi.io)" -- -b "$BIN_DIR"
    CHEZMOI="$BIN_DIR/chezmoi"
fi

if [ ! -d "$SAUCE_DIR/.git" ]; then
    log "Cloning .sauce to $SAUCE_DIR..."
    git clone "https://github.com/codyconfer/.sauce.git" "$SAUCE_DIR"
fi

if [ -f "$SAUCE_DIR/.env" ]; then
    log "Sourcing $SAUCE_DIR/.env for chezmoi config defaults..."
    source_dotenv
fi

if op_requested || bw_requested; then
    if bw_requested && ! command -v jq >/dev/null 2>&1 && [ "$DRY_RUN" = false ]; then
        log "Installing jq (the Bitwarden CLI installer needs it)..."
        install_prereqs jq || warn "Could not install jq."
    fi
    op_login
    bw_login
    if [ -f "$SAUCE_DIR/.env" ] && [ "$DRY_RUN" = false ]; then
        log "Re-reading .env now that the secret managers are available..."
        source_dotenv
    fi
fi

if [ "$DRY_RUN" = true ]; then
    log "Initializing chezmoi and validating a full apply (dry run)..."
    "$CHEZMOI" init --source="$SAUCE_DIR" --promptDefaults --no-tty
    "$CHEZMOI" apply --source="$SAUCE_DIR" --dry-run --verbose --no-tty \
        --refresh-externals=never
else
    log "Running chezmoi init --apply..."
    "$CHEZMOI" init --source="$SAUCE_DIR" --apply
fi

if [ "$DRY_RUN" = true ]; then
    echo "✅ Dry run passed. No dotfiles, packages, or applications were changed."
else
    echo "✅ Done. Start a new shell (zsh) to pick everything up."
fi
