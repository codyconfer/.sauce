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
  p_done
}

initial_packages () {
  echo "adding packages..."
  sudo pacman -Syu
  sudo pacman -S git curl wget unzip s-tui htop atop iftop iotop nvtop btop perf wavemon tailscale easyeffects
  p_done
}

dev_tools () {
  echo "installing dev tools..."
  sudo pacman -Syu
  sudo pacman -S rustup neovim gcc make python-pipx 
  pipx ensurepath
  curl -o- https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.sh | bash
  curl https://pyenv.run | bash
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  pipx install poetry
  paru -S docker-desktop visual-studio-code-bin steam discord github-cli jetbrains-toolbox lmstudio-bin obsidian bitwarden zed zen-browser deno go rslsync slack-desktop-wayland
  p_done
}

configure_shell () {
  echo "installing ohmyposh..."
  curl -s https://ohmyposh.dev/install.sh | bash -s
  p_done
  echo "configuring zsh..."
  sudo pacman -S zsh
  rm .zshrc
  cp ~/.sauce/configs/.zshrc .zshrc
  chsh -s $(which zsh)
  p_done
}

hush_login
initial_packages
dev_tools
git_config
configure_shell
