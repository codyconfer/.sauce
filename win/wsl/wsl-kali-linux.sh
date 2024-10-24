#!/bin/bash

touch ~/.hushlogin
cd ~
EMAIL=mail@codyconfer.me
sudo apt update
sudo apt install zsh git gh curl wget xz-utils unzip -y
sh <(curl -L https://nixos.org/nix/install) --daemon
curl -s https://ohmyposh.dev/install.sh | bash -s
git config --global user.name $(whoami) \
  && git config --global user.email $EMAIL \
  && gh auth setup-git
gh auth login \
  -p ssh
git clone git@github.com:codyconfer/.sauce.git
rm .zshrc
cp ~/.sauce/configs/.wsl-zshrc .zshrc
if [[ $(dpkg --print-architecture) == *arm64* ]]; then
  echo "arm64"
  sudo apt install kali-linux-arm -y
else
  echo "x86_64"
  sudo apt install kali-linux-headless -y
fi
sudo apt full-upgrade -y
chsh -s $(which zsh)
wsl.exe --shutdown
