param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$sauceDir = if ($env:SAUCE_DIR) { $env:SAUCE_DIR } else { Join-Path $HOME '.sauce' }

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget (App Installer) is required. Install it from the Microsoft Store, then re-run.'
}

function Install-WingetId($id) {
    winget list --exact --id $id --accept-source-agreements *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "+ installing $id"
        winget install --exact --id $id --silent `
            --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) {
            throw "winget failed to install $id (exit code $LASTEXITCODE)"
        }
    }
}

Install-WingetId 'Git.Git'
Install-WingetId 'twpayne.chezmoi'

$env:Path += ';' + [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
             [System.Environment]::GetEnvironmentVariable('Path', 'User')

if (-not (Test-Path (Join-Path $sauceDir '.git'))) {
    Write-Host "Cloning .sauce to $sauceDir"
    git clone 'https://github.com/codyconfer/.sauce.git' $sauceDir
}

if ($DryRun) {
    Write-Host 'Initializing chezmoi and validating a full apply (dry run)'
    chezmoi init --source="$sauceDir" --promptDefaults --no-tty
    if ($LASTEXITCODE -ne 0) { throw "chezmoi init failed (exit code $LASTEXITCODE)" }

    chezmoi apply --source="$sauceDir" --dry-run --verbose --no-tty `
        --refresh-externals=never
    if ($LASTEXITCODE -ne 0) { throw "chezmoi apply dry run failed (exit code $LASTEXITCODE)" }

    Write-Host 'Dry run passed. No dotfiles, packages, or applications were changed.'
    return
}

Write-Host 'Running chezmoi init --apply'
chezmoi init --source="$sauceDir" --apply
if ($LASTEXITCODE -ne 0) { throw "chezmoi init --apply failed (exit code $LASTEXITCODE)" }

Write-Host 'Done. Start a new pwsh session to pick up the profile.'
