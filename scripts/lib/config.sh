#! /bin/bash

APPS="${APPS:-$HOME/.apps}"
ZSH_PLUGINS="${ZSH_PLUGINS:-$HOME/.zsh}"
PROFILE_D="${PROFILE_D:-$HOME/.config/sauce/profile.d}"
DESKTOP_DIR="${DESKTOP_DIR:-$HOME/.local/share/applications}"
ICONS_DIR="${ICONS_DIR:-$HOME/.local/share/icons}"

GITHUB_USER="${GITHUB_USER:-codyconfer}"
SAUCE_DIR="${SAUCE_DIR:-$HOME/.sauce}"

STOW_DIR="${STOW_DIR:-$SAUCE_DIR/stow}"
SAUCE_USER_DIR="${SAUCE_USER_DIR:-$HOME/.config/sauce}"
SAUCE_STOW_PACKAGES=(zsh bash fish omp zsh-plugins)

DOTNET_CHANNEL="${DOTNET_CHANNEL:-LTS}"
GO_ARCH="${GO_ARCH:-linux-amd64}"
OBSIDIAN_SHA256="${OBSIDIAN_SHA256:-}"
