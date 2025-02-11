#!/bin/bash

CONFIG_REPO="git@github.com:codyconfer/.sauce.git"

git_config () {
  echo "configuring git..."
  sudo apt install git gh -y
  gh auth login -p ssh
  gh auth setup-git
  cd ~
  git clone $CONFIG_REPO
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
sh ~/.sauce/deb/setup.sh
