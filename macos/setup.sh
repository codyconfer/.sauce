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
    jetbrains-toolbox \
    jandedobbeleer/oh-my-posh/oh-my-posh
  brew update
  brew install \
    bash neovim asitop nvtop btop htop figlet mdless xz \ #cli utils
    nmap iftop tailscale \ # network tooling
    bitwarden-cli sshpass \ # secrets
    git gh make docker \ # dev workflow
    go golangci-lint govulncheck \ # go
    rustup llvm gcc \ # c/c++/rust
    nvm yarn deno oven-sh/bun/bun \ # javascript
    pyenv \ # python
    ollama lm-studio \ # llms
    mongosh \ # dbs
    azure-cli aws-cli mongodb-atlas-cli firebase-cli # cloud sdks
  brew install pipx
  pipx ensurepath
  pipx install poetry
  brew upgrade
  echo " --- "
}

configure_shell () {
  echo "refreshing zsh..."
  cd ~
  git clone $CONFIG_REPO
  rm ~/.zshrc && cp ~/.sauce/configs/.zshrc ~/.zshrc
  echo " --- "
}

homebrew
install_packages
configure_shell
