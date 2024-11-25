. .\win\config.ps1
. .\win\lib\write.ps1

function Install-Package {
  param ([string]$id, [string]$name)
  Write-Host "Installing $name..."
  winget install $id
}

function Install-Packages {
  Write-Header "Installing packages..."
  foreach ($package in $packages) {
    Install-Package $package.item1 $package.item2
  }
}
