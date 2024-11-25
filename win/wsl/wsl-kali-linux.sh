#!/bin/bash

DIV="-------------------------------------------------------------------------------"
echo "hush login..."
touch ~/.hushlogin
echo "done!"
echo $DIV
cd ~
EMAIL=mail@codyconfer.me
echo "installing packages..."
sudo apt update
sudo apt install zsh git gh curl wget xz-utils unzip -y
sudo apt upgrade -y
echo "done!"
echo $DIV
echo "installing nix..."
sh <(curl -L https://nixos.org/nix/install) --daemon
echo "done!"
echo $DIV
echo "installing ohmyposh..."
curl -s https://ohmyposh.dev/install.sh | bash -s
echo "done!"
echo $DIV
echo "configuring git..."
git config --global user.name $(whoami) \
  && git config --global user.email $EMAIL \
  && gh auth setup-git
gh auth login \
  -p ssh
git clone git@github.com:codyconfer/.sauce.git
echo "done!"
echo $DIV
echo "configuring zsh..."
rm .zshrc
cp ~/.sauce/configs/.wsl-zshrc .zshrc
echo "done!"
echo $DIV
echo "installing kali tools..."
if [[ $(dpkg --print-architecture) == *arm64* ]]; then
  echo "arm64"
  sudo apt install kali-linux-arm -y
else
  echo "x86_64"
  sudo apt install kali-linux-headless -y
fi
echo "done!"
echo $DIV
echo "configuring shell..."
sudo apt full-upgrade -y
chsh -s $(which zsh)
echo "done!"
echo $DIV
