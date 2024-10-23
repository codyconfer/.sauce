. .\powershell\config.ps1
. .\powershell\lib\write.ps1

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
      Start-Process powershell -WindowStyle Minimized -ArgumentList "&wsl --install $distro"
      Write-Host "Fill out new user information for distro in the other terminal."
    }
  }
}