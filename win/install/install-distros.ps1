. .\win\config.ps1
. .\win\lib\write.ps1

function Set-DistroConfigs {
  param([string]$distro)
  if (Test-Path "$env:USERPROFILE\$dir\win\wsl\wsl-$distro.sh") {
    $sh = "/mnt/c/Users/$env:USERNAME/$dir/win/wsl/wsl-$distro.sh"
    Write-Host "running $sh..."
    wsl -d $distro -e $sh
  }
}

function Install-Distros {
  Write-Header "Installing WSL distros..."
  wsl --update
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
