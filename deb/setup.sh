#!/bin/bash

function echo-action(action) {
  echo $action...
}

function echo-done() {
  DIV="-------------------------------------------------------------------------------"
  echo "done!"
  echo $DIV
}

function hush-login() {
  echo-action "hush login"
  touch ~/.hushlogin
  echo-done
}

function git-config() {
  echo-action "configuring git"
  gh auth login \
    -p ssh
  gh auth setup-git
  cd ~
  git clone git@github.com:codyconfer/.sauce.git
  echo-done
}

function initial-packages() {
  echo-action "adding packages"
  wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  rm packages-microsoft-prod.deb
  sudo apt update
  sudo apt install git gh curl wget xz-utils unzip -y
  sudo apt full-upgrade -y
  echo-done
}

function dev-tools() {
  echo-action "installing dev tools"
  curl -o- https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.sh | bash
  curl https://pyenv.run | bash
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  sudo apt install -y rustup golang neovim gcc make
  echo-done
}

function configure-shell() {
  echo-action "installing ohmyposh"
  curl -s https://ohmyposh.dev/install.sh | bash -s
  echo-done
  echo-action "configuring zsh"
  sudo apt install zsh -y
  rm .zshrc
  cp ~/.sauce/configs/.wsl-zshrc .zshrc
  chsh -s $(which zsh)
  echo-done
}

hush-login
initial-packages
git-config
dev-tools
configure-shell
