#!/bin/bash

DIV="-------------------------------------------------------------------------------"
echo "hush login..."
touch ~/.hushlogin
echo "done!"
echo $DIV
cd ~
EMAIL=mail@codyconfer.me
echo "installing packages..."
wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
sudo apt update
sudo apt install zsh git gh curl wget xz-utils unzip -y
sudo apt full-upgrade -y
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
echo "done!"
echo $DIV
echo "installing nix..."
sh <(curl -L https://nixos.org/nix/install) --daemon
echo "done!"
echo $DIV
git clone git@github.com:codyconfer/.sauce.git
echo "configuring zsh..."
rm .zshrc
cp ~/.sauce/configs/.wsl-zshrc .zshrc
echo "done!"
echo $DIV
echo "configuring shell..."
chsh -s $(which zsh)
echo "done!"
echo $DIV
echo "installing dev tools..."
curl -o- https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.sh | bash
curl https://pyenv.run | bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
sudo apt install -y rustup golang neovim
echo "done!"
echo $DIV
