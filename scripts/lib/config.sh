#! /bin/bash

# --- paths ---
APPS="${APPS:-$HOME/.apps}"                 # downloaded apps/AppImages; added to PATH
ZSH_PLUGINS="${ZSH_PLUGINS:-$HOME/.zsh}"    # where zsh plugins are cloned (match .zshrc)

# --- identity & dotfiles ---
GITHUB_USER="${GITHUB_USER:-codyconfer}"    # owner of your .sauce fork
SAUCE_DIR="${SAUCE_DIR:-$HOME/.sauce}"      # local dotfiles/config repo (chezmoi sourceDir)

# --- per-tool tunables ---
DOTNET_CHANNEL="${DOTNET_CHANNEL:-LTS}"     # LTS | STS | e.g. 8.0
GO_ARCH="${GO_ARCH:-linux-amd64}"           # Go tarball arch suffix
