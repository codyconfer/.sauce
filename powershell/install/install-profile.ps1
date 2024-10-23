. .\powershell\config.ps1
. .\powershell\lib\write.ps1

$newProfile = "$dir\powershell\profile.ps1"
$repo = "$gitUserUrl/.sauce.git"

function Install-Profile {
  Write-Header "Installing profile..."
  $wd = (get-location).path
  Set-Location $env:USERPROFILE
  if (Test-Path -Path $dir) {
    git fetch
    git pull
  }
  else {
    git clone $repo
  }
  if (Test-Path -Path $profile) {
    Write-Host "Removing $profile..."
    Remove-Item $profile
  }
  Write-Host "Installing $profile..."
  Copy-Item $newProfile $profile
  . $profile
  Set-Location $wd
}