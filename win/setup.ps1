################################################################################
# SETUP SCRIPT FOR WINDOWS 11 - codyconfer - 2024-10-22
################################################################################

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
  [tuple]::Create("Microsoft.VisualStudioCode", "Visual Studio Code")
  [tuple]::Create("Microsoft.VisualStudio.2022.Community", "Visual Studio 2022 Community")
)

function Install-Packages {
  Write-Host "Installing packages..."
  foreach ($package in $packages) {
    Write-Host "Installing ${package.item2}..."
    winget install $package.item1
  }
}

$fonts = @(
  "nerd-fonts-hack"
  "cascadia-code-nerd-font"
  "nerd-fonts-firacode"
  "nerd-fonts-jetbrainsmono"
  "nerd-fonts-sourcecodepro"
  "nerd-fonts-terminus"
  "nerd-fonts-robotomono"
  "nerd-fonts-ubuntumono"
  "nerd-fonts-ubuntu"
  "nerd-fonts-spacemono"
  "nerd-fonts-go-mono"
  "nerd-fonts-sharetechmono"
  "terminal-icons.powershell"
)

function Install-Fonts {
  Write-Host "Installing fonts..."
  sudo choco feature enable -n allowGlobalConfirmation
  foreach ($font in $fonts) {
    choco install $font
  }
}

$dir = ".sauce"
$gitUserUrl = "https://github.com/codyconfer"

function Write-Profile {
  param([string]$url, [string]$newUrl)
  if (Test-Path -Path $url) {
    Write-Host "Removing $url..."
    Remove-Item $url
  }
  Write-Host "Installing $url..."
  Copy-Item $newUrl $url
}

function Install-Profile {
  Write-Host "Installing profile..."
  $wd = (get-location).path
  Set-Location $env:USERPROFILE
  if (Test-Path -Path $dir) {
    Write-Host "Found $dir"
  }
  else {
    $repo = "$gitUserUrl/.sauce.git"
    git clone $repo
  }
  $newProfile = "$dir\win\profile\profile.ps1"
  Write-Profile $profile $newProfile
  . $profile
  Set-Location $wd
}

Install-Packages
Install-Fonts
Install-Profile
Write-Host "Done!"
