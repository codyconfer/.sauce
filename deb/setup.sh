#!/bin/bash

p_action () {
  echo $1...
}

function p_done {
  DIV="-------------------------------------------------------------------------------"
  echo "done!"
  echo $DIV
}

function hush_login {
  p_action "hush login"
  touch ~/.hushlogin
  p_done
}

function git_config {
  p_action "configuring git"
  gh auth login \
    -p ssh
  gh auth setup-git
  cd ~
  git clone git@github.com:codyconfer/.sauce.git
  p_done
}

function initial_packages {
  p_action "adding packages"
  wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  rm packages-microsoft-prod.deb
  sudo apt update
  sudo apt install git gh curl wget xz-utils unzip -y
  sudo apt full-upgrade -y
  p_done
}

function dev_tools {
  p_action "installing dev tools"
  curl -o- https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.sh | bash
  curl https://pyenv.run | bash
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  sudo apt install -y rustup golang neovim gcc make
  p_done
}

function configure_shell {
  p_action "installing ohmyposh"
  curl -s https://ohmyposh.dev/install.sh | bash -s
  p_done
  p_action "configuring zsh"
  sudo apt install zsh -y
  rm .zshrc
  cp ~/.sauce/configs/.wsl-zshrc .zshrc
  chsh -s $(which zsh)
  p_done
}

hush_login
initial_packages
git_config
dev_tools
configure_shell
