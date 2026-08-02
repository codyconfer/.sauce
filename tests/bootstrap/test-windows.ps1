param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir
)

$ErrorActionPreference = 'Stop'
$env:SAUCE_DIR = (Resolve-Path $SourceDir).Path
$env:SAUCE_WIN_APPS = 'vscode cursor zed obsidian docker-desktop jetbrains-toolbox ghidra ollama lmstudio slack discord signal obs-studio bitwarden zen retroarch zoom 1password'
$env:SAUCE_WIN_TOOLS = 'go dotnet aws gcloud azure-cli kubectl k9s node nvm yarn neovim gh oh-my-posh cloudflared adb 1password-cli bitwarden-cli'

$parseFiles = @(
    (Join-Path $env:SAUCE_DIR 'bootstrap.ps1'),
    (Join-Path $env:SAUCE_DIR 'home/Documents/PowerShell/Microsoft.PowerShell_profile.ps1')
)
foreach ($file in $parseFiles) {
    $tokens = $null
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $file, [ref]$tokens, [ref]$errors
    )
    if ($errors) {
        throw "PowerShell parse errors in ${file}: $($errors -join '; ')"
    }
}

& (Join-Path $env:SAUCE_DIR 'bootstrap.ps1') -DryRun
if ($LASTEXITCODE -ne 0) { throw "bootstrap.ps1 failed (exit code $LASTEXITCODE)" }

$data = chezmoi data --source="$env:SAUCE_DIR" --format=json | Out-String
if ($LASTEXITCODE -ne 0) { throw "chezmoi data failed (exit code $LASTEXITCODE)" }

$wingetTemplate = Join-Path $env:SAUCE_DIR 'home/.chezmoiscripts/run_onchange_before_40-winget.ps1.tmpl'
$renderedWinget = Get-Content -Raw $wingetTemplate |
    chezmoi execute-template --source="$env:SAUCE_DIR" | Out-String
if ($LASTEXITCODE -ne 0) { throw "winget template rendering failed (exit code $LASTEXITCODE)" }
$tokens = $null
$errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseInput(
    $renderedWinget, [ref]$tokens, [ref]$errors
)
if ($errors) { throw "Rendered winget script has parse errors: $($errors -join '; ')" }

$allSelections = "$env:SAUCE_WIN_APPS $env:SAUCE_WIN_TOOLS" -split ' '
foreach ($expected in @('family') + $allSelections) {
    $expectedJson = if ($expected -eq 'family') { '"family": "windows"' } else { "`"$expected`"" }
    if (-not $data.Contains($expectedJson)) {
        throw "Expected rendered data to contain: $expectedJson"
    }
}

Write-Host 'Full Windows bootstrap dry run passed.'
