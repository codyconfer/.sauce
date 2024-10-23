. .\powershell\config.ps1
. .\powershell\lib\write.ps1

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
  Write-Header "Installing profile..."
  $wd = (get-location).path
  Set-Location $env:USERPROFILE
  if (Test-Path -Path $dir) {
    Write-Host "Found $dir"
  }
  else {
    $repo = "$gitUserUrl/.sauce.git"
    git clone $repo
  }
  $newProfile = "$dir\powershell\profile.ps1"
  Write-Profile $profile $newProfile
  . $profile
  $termSettings = ".\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
  $newTermSettings = "$dir\configs\windows-terminal.json"
  Write-Profile $termSettings $newTermSettings
  Set-Location $wd
}
