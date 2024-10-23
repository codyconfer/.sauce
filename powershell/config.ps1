################################################################################
# SETUP CONFIG
################################################################################

. .\powershell\lib\packages.ps1

$skipFeatures = $false
$skipPackages = $false
$skipDistros = $false
$skipFonts = $false

$dir = ".sauce"
$gitUserUrl = "https://github.com/codyconfer"

# windows features (id, name)
$features = @(
  [tuple]::Create("Microsoft-Windows-Subsystem-Linux", "WSL")
)

# wsl --list --online
$distros = @(
  "kali-linux",
  "Ubuntu-24.04"
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
