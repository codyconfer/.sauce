. .\powershell\config.ps1
. .\powershell\lib\write.ps1

function Enable-Feature {
  param ([string]$id, [string]$name)
  if ((Get-WindowsOptionalFeature -Online -FeatureName $id).State -eq "Enabled") {
    Write-Host "$name is already enabled."
  }
  else {
    Write-Host "$name is not enabled. Enabling..."
    Write-Host "Restart your computer when prompted and run this script again."
    Enable-WindowsOptionalFeature -Online -FeatureName $id
    Exit
  }
}

function Enable-Features {
  Write-Header "Enabling Windows features..."
  foreach ($feature in $features) {
    Enable-Feature $($feature.item1) $($feature.item2)
  }
}