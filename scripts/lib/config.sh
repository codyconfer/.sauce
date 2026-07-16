#! /bin/bash

OPT="${OPT:-$HOME/.local/opt}"
BIN="${BIN:-$HOME/.local/bin}"
ICONS="${ICONS:-$HOME/.local/share/icons}"
CACHE="${CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/sauce}"
ZSH_PLUGINS="${ZSH_PLUGINS:-$HOME/.zsh}"

SAUCE_DIR="${SAUCE_DIR:-$HOME/.sauce}"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64)  ARCH=amd64 ;;
    aarch64|arm64) ARCH=arm64 ;;
esac

DOTNET_CHANNEL="${DOTNET_CHANNEL:-LTS}"
GO_ARCH="${GO_ARCH:-${OS}-${ARCH}}"
