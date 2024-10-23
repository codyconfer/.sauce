. ./powershell/config.ps1
. ./powershell/lib/write.ps1
. ./powershell/lib/fonts.ps1

function Install-Fonts {
  Write-Header "Installing fonts..."
  choco feature enable -n allowGlobalConfirmation
  foreach ($font in $fonts) {
    choco install $font
  }
}