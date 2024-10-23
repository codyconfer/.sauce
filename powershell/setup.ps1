################################################################################
# SETUP SCRIPT FOR WINDOWS 11 - codyconfer - 2024-10-22
################################################################################

. .\powershell\lib\write.ps1
. .\powershell\install\install-profile.ps1
. .\powershell\install\install-packages.ps1
. .\powershell\install\install-distros.ps1
. .\powershell\enable\enable-features.ps1

################################################################################
# LIFECYCLE
################################################################################
if (-not $skipFeatures) {
  Enable-Features
}
if (-not $skipPackages) {
  Install-Packages
}
if (-not $skipDistros) {
  Install-Distros
}
Install-Profile
Write-Header "Done!"
