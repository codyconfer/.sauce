#!/bin/bash

# Github user where .sauce repo fork is located
# This is not the user that will be signed into github
GITHUB_USER="codyconfer"

git_config () {
  echo "configuring git..."
  sudo apt install git gh -y
  gh auth login -p ssh
  gh auth setup-git
  cd ~
  if [ ! -d ~/.sauce ]; then
    CONFIG_REPO="git@github.com:$GITHUB_USER/.sauce.git"
    git clone $CONFIG_REPO
  fi
  echo " --- "
}

tailscale_config () {
  echo "configuring tailscale..."
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
  sudo apt update
  sudo apt install tailscale -y
  sudo tailscale up
  echo " --- "
}

git_config
tailscale_config
