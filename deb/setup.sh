#!/bin/bash

p_done () {
  DIV="-------------------------------------------------------------------------------"
  echo "done!"
  echo $DIV
}

hush_login () {
  echo "hush login..."
  touch ~/.hushlogin
  p_done
}

git_config () {
  echo "configuring git..."
  gh auth login \
    -p ssh
  gh auth setup-git
  cd ~
  git clone git@github.com:codyconfer/.sauce.git
  p_done
}

initial_packages () {
  echo "adding packages..."
  wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  rm packages-microsoft-prod.deb
  sudo apt update
  sudo apt install git gh curl wget xz-utils unzip s-tui htop atop iftop iotop nvtop btop wavemon tailscale -y
  sudo apt full-upgrade -y
  tailscale up
  p_done
}

dev_tools () {
  echo "installing dev tools..."
  sudo apt update
  sudo apt install pipx
  pipx ensurepath
  curl -o- https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.sh | bash
  curl https://pyenv.run | bash
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  sudo apt install -y rustup golang neovim gcc make
  pipx install poetry
  p_done
}

configure_shell () {
  echo "installing ohmyposh..."
  curl -s https://ohmyposh.dev/install.sh | bash -s
  p_done
  echo "configuring zsh..."
  sudo apt install zsh -y
  rm .zshrc
  cp ~/.sauce/configs/.zshrc .zshrc
  chsh -s $(which zsh)
  p_done
}

hush_login
initial_packages
git_config
dev_tools
configure_shell
