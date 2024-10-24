. ./win/config.ps1
. ./win/lib/write.ps1
. ./win/lib/fonts.ps1

function Install-Fonts {
  Write-Header "Installing fonts..."
  choco feature enable -n allowGlobalConfirmation
  foreach ($font in $fonts) {
    choco install $font
  }
}
