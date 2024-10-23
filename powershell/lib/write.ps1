function Write-Divider {
  Write-Host "--------------------------------------------------------------------------------"
  Write-Host ""
}

function Write-Header {
  param (
    [string]$title
  )
  Write-Host ""
  Write-Host "--------------------------------------------------------------------------------"
  Write-Host $title
  Write-Divider
}
