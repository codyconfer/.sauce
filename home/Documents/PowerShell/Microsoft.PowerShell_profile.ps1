$env:XDG_CONFIG_HOME = Join-Path $HOME '.config'

$env:EDITOR = 'nvim'
$env:VISUAL = 'nvim'
Set-Alias vi  nvim
Set-Alias vim nvim

$ompConfig = Join-Path $HOME '.config\oh-my-posh\sauce.toml'
if ((Get-Command oh-my-posh -ErrorAction SilentlyContinue) -and (Test-Path $ompConfig)) {
    oh-my-posh init pwsh --config $ompConfig | Invoke-Expression
}

$localProfile = Join-Path $HOME 'Documents\PowerShell\profile.local.ps1'
if (Test-Path $localProfile) {
    . $localProfile
}
