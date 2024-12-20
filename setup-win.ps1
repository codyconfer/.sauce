################################################################################
# SETUP SCRIPT FOR WINDOWS 11 - codyconfer - 2024-10-22
################################################################################

. .\win\lib\write.ps1
. .\win\profile\install-profile.ps1
. .\win\packages\install-packages.ps1
. .\win\distros\install-distros.ps1
. .\win\fonts\install-fonts.ps1

################################################################################
# LIFECYCLE
################################################################################
function Enable-Features {
  Write-Header "Enabling Windows features..."
  Write-Host "launching admin window..."
  $script = "-File `"" + $PSScriptRoot + "\features\enable-features.ps1" + "`" $PSScriptRoot\config.ps1"
  Write-Host "..."
  Start-Process powershell -Wait -ArgumentList "-noprofile", "$script" -Verb Runas
  Write-Host "done!"
}

Enable-Features
# Install-Packages
# Install-Fonts
Install-Profile
Install-Distros
Write-Header "Done!"
