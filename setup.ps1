################################################################################
# SETUP SCRIPT FOR WINDOWS 11 - codyconfer - 2024-10-22
################################################################################

################################################################################
# SCRIPT CONFIG
################################################################################

# windows features (id, name)
$features = @(
  [tuple]::Create("Microsoft-Windows-Subsystem-Linux", "WSL")
)

# wsl --list --online
$distros = @(
  "kali-linux",
  "Ubuntu-24.04"
)

# winget (id, name)
## library
$azure = @(
  [tuple]::Create("Azure.AzureCLI", "Azure CLI")
  [tuple]::Create("Azure.AzurePowerShell", "Azure PowerShell")
  [tuple]::Create("Azure.AzureStorageExplorer", "Azure Storage Explorer")
  [tuple]::Create("Azure.CLI", "Azure CLI")
  [tuple]::Create("Azure.CloudShell", "Azure Cloud Shell")
  [tuple]::Create("Azure.DataStudio", "Azure Data Studio")
  [tuple]::Create("Azure.IoTCentral", "Azure IoT Central")
  [tuple]::Create("Azure.PowerShell", "Azure PowerShell")
  [tuple]::Create("Azure.StorageExplorer", "Azure Storage Explorer")
  [tuple]::Create("Azure.VSCode", "Azure Tools for Visual Studio Code")
)
$dev = @(
  [tuple]::Create("Docker.DockerDesktop", "Docker Desktop")
  [tuple]::Create("Microsoft.WindowsTerminal", "Windows Terminal")
  [tuple]::Create("Microsoft.PowerShell", "PowerShell")
  [tuple]::Create("Microsoft.WinDbg", "WinDbg")
  [tuple]::Create("Microsoft.DevHome", "DevHome")
  [tuple]::Create("Git.Git", "Git")
  [tuple]::Create("Fork.Fork", "Git Fork")
  [tuple]::Create("GitHub.GitHubDesktop", "GitHub Desktop")
  [tuple]::Create("Postman.Postman", "Postman")
  [tuple]::Create("Unity.UnityHub", "Unity Hub")
  [tuple]::Create("JetBrains.Toolbox", "JetBrains")
  [tuple]::Create("Ollama.Ollama", "Ollama")
  [tuple]::Create("ElementLabs.LMStudio", "LM Studio")
  [tuple]::Create("Microsoft.DotNet.SDK.Preview", ".NET Preview")
  [tuple]::Create("Microsoft.DotNet.SDK.8", ".NET 8")
  [tuple]::Create("CoreyButler.NVMforWindows", "nvm")
  [tuple]::Create("DenoLand.Deno", "Deno")
  [tuple]::Create("Oven-sh.Bun", "Bun")
  [tuple]::Create("GoLang.Go", "Go")
  [tuple]::Create("GolangCI.golangci-lint", "golangci-lint")
  [tuple]::Create("zig.zig", "Zig")
  [tuple]::Create("Rustlang.Rustup", "Rustup")
)
$visualstudio = @(
  [tuple]::Create("Microsoft.VisualStudioCode", "Visual Studio Code")
  [tuple]::Create("VisualStudio.VisualStudio2022Community", "Visual Studio 2022 Community")
)
$desktop = @(
  [tuple]::Create("NZXT.CAM", "NZXT")
)
$accessories = @(
  [tuple]::Create("Logitech.GHUB", "GHUB")
  [tuple]::Create("Logitech.OptionsPlus", "Logitech Options")
)
$optionalServices = @(
  [tuple]::Create("Bitwarden.Bitwarden", "Bitwarden")
  [tuple]::Create("Bitwarden.CLI", "BitwardenCLI")
  [tuple]::Create("EpicGames.EpicGamesLauncher", "Epic Games Launcher")
  [tuple]::Create("Microsoft.Teams", "Teams")
  [tuple]::Create("Mozilla.Thunderbird", "Thunderbird")
  [tuple]::Create("OpenWhisperSystems.Signal", "Signal")
  [tuple]::Create("Plex.Plexamp", "Plexamp")
  [tuple]::Create("SlackTechnologies.Slack", "Slack")
  [tuple]::Create("tailscale.tailscale", "tailscale")
  [tuple]::Create("Vysor.Vysor", "Vysor")
)

## will install packages below
$packages = [System.Collections.ArrayList] @(
  [tuple]::Create("Chocolatey.Chocolatey", "Chocolatey")
  [tuple]::Create("Discord.Discord", "Discord")
  [tuple]::Create("Google.Chrome", "Google Chrome")
  [tuple]::Create("Libretro.RetroArch", "RetroArc")
  [tuple]::Create("MMartiCliment.UniGetUI", "UniGetUI")
  [tuple]::Create("Microsoft.Sysinternals", "Sysinternals")
  [tuple]::Create("Microsoft.PowerToys", "PowerToys")
  [tuple]::Create("Mozilla.Firefox.DeveloperEdition", "Firefox")
  [tuple]::Create("Obsidian.Obsidian", "Obsidian")
  [tuple]::Create("TorProject.TorBrowser", "Tor Browser")
  [tuple]::Create("Valve.Steam", "Steam")
  [tuple]::Create("JanDeDobbeleer.OhMyPosh", "ohmyposh")
)
$packages.AddRange($dev)
$packages.AddRange($visualstudio)

################################################################################
# Functions
################################################################################
function Write-Divider {
  Write-Host "--------------------------------------------------------------------------------"
  Write-Host ""
}

function Write-Header {
  param (
    [string]$title
  )
  Write-Host ""
  Write-Host "--------------------------------------------------------------------------------"
  Write-Host $title
  Write-Divider
}

function Enable-Feature {
  param ([string]$id, [string]$name)
  if ((Get-WindowsOptionalFeature -Online -FeatureName $id).State -eq "Enabled") {
    Write-Host "$name is already enabled."
  }
  else {
    Write-Host "$name is not enabled. Enabling..."
    Write-Host "Restart your computer when prompted and run this script again."
    Enable-WindowsOptionalFeature -Online -FeatureName $id
    Exit
  }
}

function Install-Package {
  param ([string]$id, [string]$name)
  Write-Host "Installing $name..."
  winget install $id
}

################################################################################
# LIFECYCLE
################################################################################

function Enable-Features {
  Write-Header "Enabling Windows features..."
  foreach ($feature in $features) {
    Enable-Feature $($feature.item1) $($feature.item2)
  }
}

function Install-Packages {
  Write-Header "Installing packages..."
  foreach ($package in $packages) {
    Install-Package $package.item1 $package.item2
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
      Start-Process powershell -WindowStyle Minimized -ArgumentList "&wsl --install $distro"
      Write-Host "Fill out new user information for distro in the other terminal."
    }
  }
}

function Install-Profile {
  Write-Header "Installing profile..."
  Set-Location %USERPROFILE% 
  git clone https://github.com/codyconfer/.sauce.git
  Remove-Item $profile
  Copy-Item .sauce\profile.ps1 $profile
  . $profile
}

Enable-Features
Install-Packages
Install-Distros
Install-Profile
Write-Header "Done!"
