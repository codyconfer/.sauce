#!/bin/bash

homebrew () {
  echo "adding homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo " --- "
}

install_packages () {
  echo "installing dev tools..."
  brew update
  brew install --cask android-sdk \
    mactex \
    postman \
    visual-studio-code \
    zoom \
    figma \
    obsidian \
    raycast \
    zed \
    microsoft-teams \
    powershell \
    google-cloud-sdk \
    mongodb-compass \
    wine-stable \
    slack \
    dotnet \
    jandedobbeleer/oh-my-posh/oh-my-posh
  brew update
  brew install \
    git gh \
    go rustup nvm pyenv llvm bash yarn deno oven-sh/bun/bun \
    neovim nmap asitop iftop nvtop btop htop figlet mdless \
    bitwarden-cli mongosh ollama sshpass tailscale xz  \
    azure-cli mongodb-atlas-cli firebase-cli 
  brew install pipx
  pipx ensurepath
  pipx install poetry
  brew upgrade
  echo " --- "
}

configure_shell () {
  echo "refreshing zsh..."
  rm ~/.zshrc && cp ~/.sauce/configs/.zshrc ~/.zshrc
  echo " --- "
}

homebrew
install_packages
configure_shell
