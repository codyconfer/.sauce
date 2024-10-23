$HasOhMyPosh = $true
$HasChocolatey = $true

if ($HasOhMyPosh) {
  oh-my-posh init pwsh --config "~/.sauce/themes/ohmyposh-sauce.toml" | Invoke-Expression
  Import-Module -Name Terminal-Icons
}

if ($HasChocolatey) {
  $ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
  if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
  }
}

#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module
Import-Module -Name Microsoft.WinGet.CommandNotFound
#f45873b3-b655-43a6-b217-97c00aa0db58


