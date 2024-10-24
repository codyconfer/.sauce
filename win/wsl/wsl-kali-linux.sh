#!/bin/bash

touch ~/.hushlogin
cd ~
EMAIL=mail@codyconfer.me
sudo apt update
sudo apt full-upgrade -y
sudo apt install zsh git gh curl wget neovim unzip -y
if [[ $(dpkg --print-architecture) == *arm64* ]]; then
  echo "arm64"
  sudo apt install kali-linux-arm -y
else
  echo "x86_64"
  sudo apt install kali-linux-headless -y
fi
git config --global user.name $(whoami) \
  && git config --global user.email $EMAIL \
  && gh auth setup-git
gh auth login \
  -p ssh
git clone git@github.com:codyconfer/.sauce.git
curl -s https://ohmyposh.dev/install.sh | bash -s
rm .zshrc
cp ~/.sauce/configs/.wsl-zshrc .zshrc
chsh -s $(which zsh)
