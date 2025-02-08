#!/bin/bash

p-action () {
  echo $1...
}

function p-done {
  DIV="-------------------------------------------------------------------------------"
  echo "done!"
  echo $DIV
}

function hush-login {
  p-action "hush login"
  touch ~/.hushlogin
  p-done
}

function git-config {
  p-action "configuring git"
  gh auth login \
    -p ssh
  gh auth setup-git
  cd ~
  git clone git@github.com:codyconfer/.sauce.git
  p-done
}

function initial-packages {
  p-action "adding packages"
  wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  rm packages-microsoft-prod.deb
  sudo apt update
  sudo apt install git gh curl wget xz-utils unzip -y
  sudo apt full-upgrade -y
  p-done
}

function dev-tools {
  p-action "installing dev tools"
  curl -o- https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.sh | bash
  curl https://pyenv.run | bash
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  sudo apt install -y rustup golang neovim gcc make
  p-done
}

function configure-shell {
  p-action "installing ohmyposh"
  curl -s https://ohmyposh.dev/install.sh | bash -s
  p-done
  p-action "configuring zsh"
  sudo apt install zsh -y
  rm .zshrc
  cp ~/.sauce/configs/.wsl-zshrc .zshrc
  chsh -s $(which zsh)
  p-done
}

hush-login
initial-packages
git-config
dev-tools
configure-shell
