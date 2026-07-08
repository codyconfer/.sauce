$ErrorActionPreference = 'Stop'

$sauceDir = Join-Path $HOME '.sauce'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget (App Installer) is required. Install it from the Microsoft Store, then re-run.'
}

function Install-WingetId($id) {
    winget list --exact --id $id --accept-source-agreements *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "+ installing $id"
        winget install --exact --id $id --silent `
            --accept-source-agreements --accept-package-agreements
    }
}

Install-WingetId 'Git.Git'
Install-WingetId 'twpayne.chezmoi'

$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path', 'User')

if (-not (Test-Path (Join-Path $sauceDir '.git'))) {
    Write-Host "Cloning .sauce to $sauceDir"
    git clone 'https://github.com/codyconfer/.sauce.git' $sauceDir
}

Write-Host 'Running chezmoi init --apply'
chezmoi init --source="$sauceDir" --apply

Write-Host 'Done. Start a new pwsh session to pick up the profile.'
