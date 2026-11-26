# Runs setup-terminal-windows.ps1 twice from Windows PowerShell 5.1, then checks the result.
# Usage, on a throwaway Windows machine such as a GitHub runner: pwsh tests/windows.ps1
$repo = Split-Path -Parent $PSScriptRoot
$fails = 0

# GitHub's Windows images have no winget
if (-not (Get-Command winget -ErrorAction Ignore)) {
  Install-PSResource Microsoft.WinGet.Client -TrustRepository -Quiet
  Repair-WinGetPackageManager -AllUsers -Latest
  $env:Path += ";$env:LOCALAPPDATA\Microsoft\WindowsApps"
}

# Seed an old PowerShell history to check the one-time atuin import
$history = Join-Path $env:APPDATA 'Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt'
New-Item -ItemType Directory -Force (Split-Path $history) | Out-Null
Set-Content $history 'echo history-from-powershell'

# Windows Terminal is missing on Windows Server: a settings.json as it creates one stands in for it
$wt = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'
New-Item -ItemType Directory -Force $wt | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'windows-terminal.json') (Join-Path $wt 'settings.json')

function Get-BackupCount { @(Get-ChildItem $HOME -Recurse -Force -Filter '*.bak-*' -ErrorAction Ignore).Count }

foreach ($run in 1, 2) {
  Write-Host "::group::run $run"
  $log = powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'setup-terminal-windows.ps1') 2>&1
  $log | ForEach-Object { Write-Host $_ }
  Write-Host '::endgroup::'
  $log | Where-Object { "$_".Contains('[!!]') } | ForEach-Object { Write-Host "::warning::run ${run}: $_" }
  if ($run -eq 1) { $afterFirst = Get-BackupCount } else { $afterSecond = Get-BackupCount }
}
if ($afterFirst -ne $afterSecond) {
  Write-Host "::error::second run backed up files that did not change ($afterFirst then $afterSecond backups)"
  Get-ChildItem $HOME -Recurse -Force -Filter '*.bak-*' -ErrorAction Ignore | ForEach-Object { Write-Host $_.FullName }
  $fails = 1
}

pwsh -NoProfile -File (Join-Path $PSScriptRoot 'check.ps1')
if ($LASTEXITCODE -ne 0) { $fails = 1 }
exit $fails
