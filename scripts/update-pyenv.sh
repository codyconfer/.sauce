#! /bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"

cleanup() {
    log_clean "Removing pyenv..."
    remove_paths "$PYENV_ROOT"
    log_done "pyenv removed."
}
dispatch_remove "$@"

if [ -d "$PYENV_ROOT/.git" ]; then
    log_download "Updating existing pyenv install in $PYENV_ROOT..."
    git -C "$PYENV_ROOT" pull --ff-only
    for plugin in "$PYENV_ROOT"/plugins/*/; do
        [ -d "$plugin/.git" ] && git -C "$plugin" pull --ff-only || true
    done
else
    log_download "Running the official pyenv installer..."
    fetch https://pyenv.run | bash
fi

export PYENV_ROOT
export PATH="$PYENV_ROOT/bin:$PATH"

if ! command -v pyenv >/dev/null 2>&1; then
    log_error "pyenv is not on PATH after install."
    exit 1
fi
pyenv --version

log_install "Installing CPython build dependencies (best-effort)..."
case "$(detect_family)" in
    debian) install_pkgs build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
        libsqlite3-dev libncursesw5-dev tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev \
        || log_warn "some build dependencies were unavailable." ;;
    fedora) install_pkgs zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel \
        openssl-devel tk-devel libffi-devel xz-devel gdbm-devel ncurses-devel patch \
        || log_warn "some build dependencies were unavailable." ;;
    arch)   install_pkgs base-devel openssl zlib xz tk \
        || log_warn "some build dependencies were unavailable." ;;
    macos)  install_pkgs openssl readline sqlite3 xz zlib tcl-tk \
        || log_warn "some build dependencies were unavailable." ;;
esac

LATEST=$(pyenv install --list | tr -d ' ' | grep -E '^3\.[0-9]+\.[0-9]+$' | tail -n1)
if [ -z "$LATEST" ]; then
    log_error "Could not resolve the latest CPython version."
    exit 1
fi
log_found "Latest CPython: $LATEST"

if grep -qx "$LATEST" <<<"$(pyenv versions --bare)"; then
    log_info "Python $LATEST is already installed."
else
    log_install "Building Python $LATEST (this takes a few minutes)..."
    pyenv install "$LATEST" || { log_error "Python $LATEST build failed."; exit 1; }
fi

log_install "Setting Python $LATEST as the pyenv global..."
pyenv global "$LATEST"
pyenv rehash

log_done
"$PYENV_ROOT/shims/python" --version
log_hint "Restart your shell to load pyenv (PYENV_ROOT is set in your rc files)."
