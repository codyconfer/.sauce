# windows features (id, name)
$features = @(
  [tuple]::Create("Microsoft-Windows-Subsystem-Linux", "WSL")
)

function Enable-Features {
  foreach ($feature in $features) {
    if ((Get-WindowsOptionalFeature -Online -FeatureName $feature.item1).State -eq "Enabled") {
      Write-Host "${feature.item2} is already enabled."
    }
    else {
      Write-Host "${feature.item2} is not enabled. Enabling..."
      Write-Host "Restart your computer when prompted and run this script again."
      Enable-WindowsOptionalFeature -Online -FeatureName $feature.item1
      Exit
    }
  }
  Write-Host "Done!"
  $k = Read-Host "Press any key to continue..."
  Write-Host ""
  Exit-PSHostProcess
}

# wsl --list --online
$distros = @(
  "kali-linux"
  "Ubuntu-24.04"
)

function Set-DistroConfigs {
  param([string]$distro)
  $debPath = "/mnt/c/users/$env:USERNAME/$dir/deb"
  $wslPath = "/mnt/c/users/$env:USERNAME/$dir/wsl"
  $debSetup = "$debPath/setup.sh"
  $debAuth = "$debPath/auth.sh"
  $debZsh = "$debPath/zsh.sh"
  $setup = "$wslPath/wsl-$distro.sh"
  $systemd = "$wslPath/wsl-systemd.sh"
  Write-Host "running $systemd..."
  wsl -u root -d $distro -e $systemd
  wsl --terminate $distro
  if (Test-Path "$env:USERPROFILE\$dir\wsl\wsl-$distro.sh") {
    Write-Host "running $setup..."
    wsl -d $distro -e $setup
    wsl --terminate $distro
  }
  Write-Host "running $distro setup..."
  wsl -d $distro -e $debAuth
  wsl -d $distro -e $debSetup
  wsl -d $distro -e $debZsh
  wsl --terminate $distro
}

function Install-Distros {
  Write-Host "Installing WSL distros..."
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

Enable-Features
Install-Distros
