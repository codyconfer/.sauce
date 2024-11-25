################################################################################
# SETUP CONFIG
################################################################################

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
  "kali-linux"
  "Ubuntu-24.04"
)

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
