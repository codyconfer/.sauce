#!/bin/bash

# Github user where .sauce repo fork is located
GITHUB_USER="codyconfer"

hush_login () {
  echo "hush login..."
  touch ~/.hushlogin
  echo " --- "
}

initial_packages () {
  echo "adding packages..."
  sudo apt install curl wget xz-utils unzip figlet -y
  wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  rm packages-microsoft-prod.deb
  sudo apt update
  sudo apt install s-tui htop atop iftop iotop nvtop btop wavemon git -y
  sudo apt full-upgrade -y
  echo " --- "
}

dev_tools () {
  echo "installing dev tools..."
  sudo apt update
  sudo apt install pipx -y
  pipx ensurepath
  curl -o- https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.sh | bash
  curl https://pyenv.run | bash
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  sudo apt install rustup golang neovim gcc make -y
  pipx install poetry
  echo " --- "
}

configure_shell () {
  if [ ! -d ~/.sauce ]; then
    CONFIG_REPO="https://github.com/$GITHUB_USER/.sauce.git"
    echo "cloning config repo..."
    git clone $CONFIG_REPO
  fi
  echo "installing ohmyposh..."
  curl -s https://ohmyposh.dev/install.sh | bash -s
  echo " --- "
  echo "installing zsh..."
  sudo apt install zsh -y
  echo " --- "
  echo "refreshing zsh..."
  if [ -f ~/.zshrc ]; then
    rm ~/.zshrc
  fi
  cp ~/.sauce/configs/.zshrc ~/.zshrc
  chsh -s $(which zsh)
  echo " --- "
}

hush_login
initial_packages
dev_tools
configure_shell
