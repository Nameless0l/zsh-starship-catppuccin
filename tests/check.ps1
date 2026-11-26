# Checks the current user's setup after setup-terminal-windows.ps1 ran.
# Usage: pwsh tests/check.ps1
$repo = Split-Path -Parent $PSScriptRoot
$script:fails = 0
function Pass($what) { Write-Host "ok    $what" }
function Fail($what) { Write-Host "::error::$what"; $script:fails++ }
function Check($actual, $expected, $what) {
  if ("$actual" -ceq "$expected") { Pass $what } else { Fail "${what}: expected '$expected', got '$actual'" }
}
function Same($source, $target) {
  if ($target -and (Test-Path $target) -and (Get-FileHash (Join-Path $repo $source)).Hash -eq (Get-FileHash $target).Hash) {
    Pass $target
  } else {
    Fail "$target is missing or differs from $source"
  }
}
function Has($command) { [bool](Get-Command $command -ErrorAction Ignore) }
function Capture($lines, $pattern) {
  $m = $lines | Select-String -Pattern $pattern | Select-Object -First 1
  if ($m) { $m.Matches[0].Groups[1].Value }
}
# A new pwsh with the profile, as in a new terminal tab
function Invoke-WithProfile($code) { (pwsh -NoLogo -Command $code 2>&1 | Out-String).Trim() }

# Installers wrote the new PATH to the registry, not to this process
$registry = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
foreach ($dir in $registry -split ';') {
  if ($dir -and ($env:Path -split ';') -notcontains $dir) { $env:Path += ";$dir" }
}

Same config/profile.ps1 $PROFILE.CurrentUserCurrentHost
Same config/starship.toml (Join-Path $HOME '.config\starship.toml')
Same eza/theme.yml (Join-Path $env:APPDATA 'eza\theme.yml')

foreach ($tool in 'git', 'starship', 'eza', 'fzf', 'zoxide', 'bat', 'fd', 'rg', 'delta', 'lazygit', 'glow', 'fastfetch', 'tldr', 'atuin') {
  if (Has $tool) { Pass "$tool installed" } else { Fail "$tool not installed" }
}
if (Get-Module -ListAvailable PSFzf) { Pass 'PSFzf installed' } else { Fail 'PSFzf not installed' }
$fonts = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts', 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
if ($fonts | Where-Object { (Test-Path $_) -and ((Get-Item $_).GetValueNames() -like 'JetBrainsMono NF *') }) {
  Pass 'JetBrainsMono Nerd Font installed'
} else {
  Fail 'JetBrainsMono Nerd Font not installed'
}

Check (Invoke-WithProfile 'exit') '' 'pwsh starts without output'
Check (Invoke-WithProfile '(Get-Command ls).CommandType') 'Function' 'ls goes through eza'
Check (Invoke-WithProfile '(Get-Command lg).CommandType') 'Alias' 'lg alias for lazygit'
Check (Invoke-WithProfile '[bool](Get-Command Enable-TransientPrompt -ErrorAction Ignore)') 'True' 'Starship prompt loaded'
if (Has zoxide) {
  Check (Invoke-WithProfile '(Get-Command cd).Definition') '__zoxide_z' 'cd goes through zoxide'
}

# PSReadLine only loads in a console, so it is imported by hand before the profile
$keys = pwsh -NoLogo -NoProfile -Command {
  Import-Module PSReadLine
  . $PROFILE 2>$null
  foreach ($chord in 'Tab', 'Ctrl+t', 'Ctrl+r', 'Enter') {
    $h = Get-PSReadLineKeyHandler -Chord $chord
    "$chord => $($h.Function) $($h.Description)"
  }
} 2>&1
$keys | ForEach-Object { Write-Host "      $_" }
if (($keys | Where-Object { $_ -like 'Tab =>*' }) -match 'FzfTabCompletion') { Pass 'Tab opens fzf' } else { Fail 'Tab does not open fzf' }
if (($keys | Where-Object { $_ -like 'Ctrl+t =>*' }) -match 'Fzf') { Pass 'Ctrl+T opens fzf' } else { Fail 'Ctrl+T does not open fzf' }
if (Has atuin) {
  if (($keys | Where-Object { $_ -like 'Ctrl+r =>*' }) -match 'Atuin') { Pass 'Ctrl+R opens atuin' } else { Fail 'Ctrl+R does not open atuin' }
}
if (($keys | Where-Object { $_ -like 'Enter =>*' }) -match 'TransientPrompt') { Pass 'transient prompt on Enter' } else { Fail 'no transient prompt on Enter' }

if (Has starship) {
  Push-Location $env:TEMP
  $warnings = starship prompt 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | Out-String
  Pop-Location
  Check $warnings.Trim() '' 'starship prompt without warnings'
}

if (Has eza) {
  $d = New-Item -ItemType Directory -Force (Join-Path $env:TEMP "eza-check-$PID")
  New-Item -ItemType Directory -Force (Join-Path $d 'src') | Out-Null
  foreach ($f in 'Cargo.toml', 'package.json', 'main.rs') { New-Item -ItemType File -Force (Join-Path $d $f) | Out-Null }
  $env:LS_COLORS = ''
  $themed = eza --icons=always --color=always $d | Out-String
  $env:EZA_CONFIG_DIR = Join-Path $env:TEMP 'nonexistent'
  $plain = eza --icons=always --color=always $d | Out-String
  Remove-Item Env:EZA_CONFIG_DIR, Env:LS_COLORS -ErrorAction Ignore
  if ($themed -ne $plain) { Pass 'eza theme applied' } else { Fail 'eza theme has no effect' }
  Remove-Item -Recurse -Force $d
}

if (Has lazygit) {
  Same config/lazygit.yml (Join-Path (lazygit --print-config-dir) 'config.yml')
}

if (Has atuin) {
  $config = (Capture (atuin info 2>$null) 'client config: "(.+)"') -replace '\\\\', '\'
  Same config/atuin/config.toml $config
  Same config/atuin/themes/catppuccin-mocha-mauve.toml (Join-Path (Split-Path $config) 'themes\catppuccin-mocha-mauve.toml')
  $env:ATUIN_SESSION = atuin uuid
  Check ((atuin search --cmd-only 'history-from-powershell' 2>&1 | Out-String).Trim()) 'echo history-from-powershell' 'PowerShell history imported into atuin'
  Remove-Item Env:ATUIN_SESSION
}

if (Has tldr) {
  Same config/tealdeer.toml (Capture (tldr --show-paths) '^Config path:\s+(.+) \(')
  if ((tldr --color always tar 2>&1 | Out-String).Contains('38;2;203;166;247m')) {
    Pass 'tldr pages with Catppuccin colors'
  } else {
    Fail 'tldr tar did not print a page in Catppuccin colors'
  }
}

if (Has delta) {
  Check (git config --global core.pager) 'delta' 'git uses delta'
}

$wt = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
if (Test-Path $wt) {
  $s = Get-Content -Raw $wt | ConvertFrom-Json
  Check (@($s.schemes | Where-Object name -EQ 'Catppuccin Mocha').Count) 1 'Windows Terminal has the Catppuccin Mocha scheme'
  Check $s.profiles.defaults.font.face 'JetBrainsMono Nerd Font' 'Windows Terminal font'
  $pwsh = $s.profiles.list | Where-Object source -EQ 'Windows.Terminal.PowershellCore' | Select-Object -First 1
  Check $pwsh.colorScheme 'Catppuccin Mocha' 'PowerShell 7 profile in Catppuccin Mocha'
  Check $s.defaultProfile $pwsh.guid 'Windows Terminal opens PowerShell 7'
}

if ($script:fails -eq 0) { Write-Host 'all checks passed' }
exit $script:fails
