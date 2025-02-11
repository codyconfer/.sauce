#!/bin/bash

CONFIG_REPO="git@github.com:codyconfer/.sauce.git"

test () {
  echo hi
}

git_config () {
  echo "configuring git..."
  brew update
  brew install git gh
  gh auth login -p ssh
  gh auth setup-git
  cd ~
  git clone $CONFIG_REPO
  echo " --- "
}

tailscale_config () {
  echo "configuring tailscale..."
  brew update
  brew install tailscale
  tailscale up
  echo " --- "
}

test
