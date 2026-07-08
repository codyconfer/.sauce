#! /bin/bash

# --- paths ---
OPT="${OPT:-$HOME/.local/opt}"
BIN="${BIN:-$HOME/.local/bin}"
ICONS="${ICONS:-$HOME/.local/share/icons}"
CACHE="${CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/sauce}"
ZSH_PLUGINS="${ZSH_PLUGINS:-$HOME/.zsh}"    # where zsh plugins are cloned (match .zshrc)

# --- identity & dotfiles ---
SAUCE_DIR="${SAUCE_DIR:-$HOME/.sauce}"      # local dotfiles/config repo (chezmoi sourceDir)

# --- per-tool tunables ---
DOTNET_CHANNEL="${DOTNET_CHANNEL:-LTS}"     # LTS | STS | e.g. 8.0
GO_ARCH="${GO_ARCH:-linux-amd64}"           # Go tarball arch suffix
