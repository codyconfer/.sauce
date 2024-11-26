#!/bin/bash

DIV="-------------------------------------------------------------------------------"
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
