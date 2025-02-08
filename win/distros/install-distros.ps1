. .\win\config.ps1
. .\win\lib\write.ps1

function Set-DistroConfigs {
  param([string]$distro)
  $debPath = "/mnt/c/users/$env:USERNAME/$dir/deb"
  $shPath = "/mnt/c/users/$env:USERNAME/$dir/win/wsl"
  $common = "$debPath/setup.sh"
  $setup = "$shPath/wsl-$distro.sh"
  $systemd = "$shPath/wsl-systemd.sh"
  Write-Host "running $systemd..."
  wsl -u root -d $distro -e $systemd
  wsl --terminate $distro
  if (Test-Path "$env:USERPROFILE\$dir\win\wsl\wsl-$distro.sh") {
    Write-Host "running $setup..."
    wsl -d $distro -e $setup
    wsl --terminate $distro
  }
  Write-Host "running $common..."
  wsl -d $distro -e $common
  wsl --terminate $distro
}

function Install-Distros {
  Write-Header "Installing WSL distros..."
  wsl --update
  wsl -v
  $env:WSL_UTF8 = 1
  foreach ($distro in $distros) {
    if (wsl --list | Select-String -Pattern $distro) {
      Write-Host "$distro is already installed."
    }
    else {
      Write-Host "Launching $distro install..."
      Start-Process powershell -Wait -ArgumentList "&wsl --install $distro"
      Write-Host "Fill out new user information for distro in the other terminal."
      Set-DistroConfigs $distro
    }
  }
}
