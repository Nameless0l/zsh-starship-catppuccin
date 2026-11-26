# Config terminal pour Windows : PowerShell 7, Starship, outils, Windows Terminal en Catppuccin Mocha.
# Usage, dans PowerShell :
#   irm https://raw.githubusercontent.com/Nameless0l/zsh-starship-catppuccin/main/setup-terminal-windows.ps1 | iex
# Depuis un clone : powershell -ExecutionPolicy Bypass -File setup-terminal-windows.ps1
# Relançable sans risque : chaque fichier remplacé est d'abord sauvegardé en .bak daté.
# Windows PowerShell 5.1 lit ce fichier en ANSI : ses messages restent sans accents jusqu'au passage à PowerShell 7.

function Write-Titre($texte) {
  Write-Host ""
  Write-Host "== $texte =="
}

function Save-Copie($fichier) {
  if (Test-Path $fichier) {
    Copy-Item $fichier "$fichier.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
  }
}

# Les installations de winget ne sont pas encore dans le PATH de ce processus
function Sync-Chemin {
  $actuels = $env:Path -split ';'
  $registre = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
  foreach ($dossier in $registre -split ';') {
    if ($dossier -and $actuels -notcontains $dossier) {
      $env:Path += ";$dossier"
    }
  }
}

# Paquet winget $id, sauté si la commande $commande existe déjà
function Install-Paquet($id, $commande) {
  if ($commande -and (Get-Command $commande -ErrorAction Ignore)) {
    return
  }
  Write-Host "[..] $id"
  $options = 'install', '--id', $id, '--exact', '--source', 'winget', '--silent',
    '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'
  $encodage = [Console]::OutputEncoding
  [Console]::OutputEncoding = [Text.Encoding]::UTF8
  # Pour l'utilisateur seul si le paquet le permet, sinon Windows demande l'autorisation
  $sortie = winget @options --scope user 2>&1
  if ($LASTEXITCODE -ne 0) {
    $sortie = winget @options 2>&1
  }
  $code = $LASTEXITCODE
  [Console]::OutputEncoding = $encodage
  Sync-Chemin
  if ($commande) {
    $ok = [bool](Get-Command $commande -ErrorAction Ignore)
  } else {
    # -1978335189 : paquet déjà installé, sans mise à jour
    $ok = $code -eq 0 -or $code -eq -1978335189
  }
  if ($ok) {
    Write-Host "[ok] $id"
  } else {
    Write-Host "[!!] winget n'a pas pu installer $id :"
    $sortie | Where-Object { "$_".Trim() } | Select-Object -Last 3 | ForEach-Object { Write-Host "     $_" }
  }
}

# Fichiers de config pris à côté du script s'il vient d'un clone du dépôt, sinon sur GitHub
$DepotUrl = 'https://raw.githubusercontent.com/Nameless0l/zsh-starship-catppuccin/main'
$DepotLocal = ''
if ($PSCommandPath -and (Test-Path (Join-Path (Split-Path $PSCommandPath) 'config\profile.ps1'))) {
  $DepotLocal = Split-Path $PSCommandPath
}

function Install-Config($source, $cible) {
  $tmp = (New-TemporaryFile).FullName
  if ($DepotLocal -and (Test-Path (Join-Path $DepotLocal $source))) {
    Copy-Item (Join-Path $DepotLocal $source) $tmp -Force
  } else {
    try {
      Invoke-WebRequest "$DepotUrl/$source" -OutFile $tmp -UseBasicParsing -ErrorAction Stop
    } catch {
      Clear-Content $tmp
    }
  }
  if ((Get-Item $tmp).Length -gt 0) {
    New-Item -ItemType Directory -Force (Split-Path $cible) | Out-Null
    if (-not (Test-Path $cible) -or (Get-FileHash $tmp).Hash -ne (Get-FileHash $cible).Hash) {
      Save-Copie $cible
      Copy-Item $tmp $cible -Force
    }
    Write-Host "[ok] $cible"
  } else {
    Write-Host "[!!] $source non récupéré, $cible inchangé"
  }
  Remove-Item $tmp -ErrorAction Ignore
}

# Clé $nom de l'objet JSON $objet : modifiée sur place si elle existe, ajoutée à la fin sinon
function Edit-Cle($objet, $nom, $valeur) {
  if ($objet.PSObject.Properties[$nom]) {
    $objet.$nom = $valeur
  } else {
    $objet | Add-Member -NotePropertyName $nom -NotePropertyValue $valeur
  }
}

# Premier groupe de la première ligne de $lignes qui correspond à $motif
function Get-Capture($lignes, $motif) {
  $m = $lignes | Select-String -Pattern $motif | Select-Object -First 1
  if ($m) {
    $m.Matches[0].Groups[1].Value
  }
}

if ($env:OS -ne 'Windows_NT') {
  Write-Host "Ce script est pour Windows. Sous Linux : setup-terminal.sh, setup-terminal-ssh.sh ou setup-terminal-wsl.sh."
  return
}
Sync-Chemin
if (-not (Get-Command winget -ErrorAction Ignore)) {
  Write-Host "[!!] winget manque : installer App Installer depuis le Microsoft Store, puis relancer ce script."
  return
}

# ---------- PowerShell 7, qui lance ensuite la suite du script ----------
if ($PSVersionTable.PSVersion.Major -lt 7) {
  Write-Titre 'PowerShell 7'
  Install-Paquet Microsoft.PowerShell pwsh
  $pwsh = Get-Command pwsh -ErrorAction Ignore
  if (-not $pwsh) {
    Write-Host "[!!] PowerShell 7 manque toujours, le reste du script en a besoin."
    return
  }
  $fichier = $PSCommandPath
  if (-not $fichier) {
    $fichier = Join-Path $env:TEMP "setup-terminal-windows-$PID.ps1"
    Invoke-WebRequest "$DepotUrl/setup-terminal-windows.ps1" -OutFile $fichier -UseBasicParsing
  }
  & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $fichier
  return
}

# ---------- Paquets ----------
Write-Titre 'Paquets winget'
$paquets = [ordered]@{
  'Git.Git'                 = 'git'
  'Starship.Starship'       = 'starship'
  'eza-community.eza'       = 'eza'
  'junegunn.fzf'            = 'fzf'
  'ajeetdsouza.zoxide'      = 'zoxide'
  'sharkdp.bat'             = 'bat'
  'sharkdp.fd'              = 'fd'
  'BurntSushi.ripgrep.MSVC' = 'rg'
  'dandavison.delta'        = 'delta'
  'JesseDuffield.lazygit'   = 'lazygit'
  'charmbracelet.glow'      = 'glow'
  'Fastfetch-cli.Fastfetch' = 'fastfetch'
  'sharkdp.hyperfine'       = 'hyperfine'
  'dbrgn.tealdeer'          = 'tldr'
  'Atuinsh.Atuin'           = 'atuin'
}
foreach ($id in $paquets.Keys) {
  Install-Paquet $id $paquets[$id]
}

# ---------- Police ----------
Write-Titre 'Police'
$Police = 'JetBrainsMono Nerd Font'
# Windows l'enregistre sous son nom court, JetBrainsMono NF
$cles = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts', 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
if ($cles | Where-Object { (Test-Path $_) -and ((Get-Item $_).GetValueNames() -like 'JetBrainsMono NF *') }) {
  Write-Host "[ok] $Police déjà installée"
} else {
  Install-Paquet DEVCOM.JetBrainsMonoNerdFont
}

# ---------- PSFzf : Tab, Ctrl+T et Alt+C dans fzf ----------
Write-Titre 'PSFzf'
if (Get-Module -ListAvailable PSFzf) {
  Write-Host "[ok] PSFzf déjà installé"
} else {
  try {
    if (Get-Command Install-PSResource -ErrorAction Ignore) {
      Install-PSResource PSFzf -Scope CurrentUser -TrustRepository -Quiet -ErrorAction Stop
    } else {
      Install-Module PSFzf -Scope CurrentUser -Force -ErrorAction Stop
    }
    Write-Host "[ok] PSFzf installé"
  } catch {
    Write-Host "[!!] PSFzf non installé : $($_.Exception.Message)"
  }
}

# ---------- Windows Terminal : police Nerd Font et couleurs Catppuccin Mocha ----------
Write-Titre 'Windows Terminal'
$Schema = [ordered]@{
  name = 'Catppuccin Mocha'; cursorColor = '#F5E0DC'; selectionBackground = '#585B70'
  background = '#1E1E2E'; foreground = '#CDD6F4'
  black = '#45475A'; red = '#F38BA8'; green = '#A6E3A1'; yellow = '#F9E2AF'
  blue = '#89B4FA'; purple = '#F5C2E7'; cyan = '#94E2D5'; white = '#BAC2DE'
  brightBlack = '#585B70'; brightRed = '#F38BA8'; brightGreen = '#A6E3A1'; brightYellow = '#F9E2AF'
  brightBlue = '#89B4FA'; brightPurple = '#F5C2E7'; brightCyan = '#94E2D5'; brightWhite = '#A6ADC8'
}
$Pwsh7 = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'
$WindowsPowerShell = '{61c54bbd-c2c6-5271-96e7-009a87ff44bf}'
$Cmd = '{0caa0dad-35be-5f56-a8ff-afceeeaa6101}'
$WtManuel = $true
Add-Type -AssemblyName System.Text.Json
$reglages = foreach ($paquet in 'Microsoft.WindowsTerminal_8wekyb3d8bbwe', 'Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe') {
  $dossier = Join-Path $env:LOCALAPPDATA "Packages\$paquet"
  if (Test-Path $dossier) {
    Join-Path $dossier 'LocalState\settings.json'
  }
}
if (-not $reglages) {
  Write-Host "[..] Windows Terminal absent"
}
foreach ($fichier in $reglages) {
  $texte = '{}'
  if (Test-Path $fichier) {
    $texte = "$(Get-Content -Raw $fichier)"
  }
  if (-not $texte.Trim()) {
    $texte = '{}'
  }
  try {
    [System.Text.Json.JsonDocument]::Parse($texte, [System.Text.Json.JsonDocumentOptions]::new()).Dispose()
  } catch {
    Write-Host "[!!] $fichier contient des commentaires ou des virgules en trop, il n'est pas modifié"
    continue
  }
  $d = $texte | ConvertFrom-Json
  $avant = $d | ConvertTo-Json -Depth 100

  $schemas = @(@($d.schemes) | Where-Object { $_ -and $_.name -ne $Schema.name }) + [pscustomobject]$Schema
  Edit-Cle $d schemes $schemas

  if ($null -eq $d.profiles) {
    Edit-Cle $d profiles ([pscustomobject]@{})
  } elseif ($d.profiles -is [array]) {
    $d.profiles = [pscustomobject]@{ defaults = [pscustomobject]@{}; list = $d.profiles }
  }
  $profils = $d.profiles
  if ($null -eq $profils.defaults) {
    Edit-Cle $profils defaults ([pscustomobject]@{})
  }
  if ($null -eq $profils.defaults.font) {
    Edit-Cle $profils.defaults font ([pscustomobject]@{})
  }
  Edit-Cle $profils.defaults.font face $Police

  $liste = @(@($profils.list) | Where-Object { $_ })
  $pwshProfil = $liste | Where-Object { $_.source -eq 'Windows.Terminal.PowershellCore' } | Select-Object -First 1
  if (-not $pwshProfil -and (Test-Path "$env:ProgramFiles\PowerShell\7\pwsh.exe")) {
    # Profil que Windows Terminal ajoute à son prochain lancement, réglé dès maintenant
    $pwshProfil = [pscustomobject]@{ guid = $Pwsh7; name = 'PowerShell'; source = 'Windows.Terminal.PowershellCore' }
    $liste += $pwshProfil
  }
  foreach ($p in $liste) {
    if ($p.source -eq 'Windows.Terminal.PowershellCore' -or $p.guid -eq $WindowsPowerShell) {
      Edit-Cle $p colorScheme $Schema.name
    }
  }
  Edit-Cle $profils list $liste

  # PowerShell 7 remplace Windows PowerShell ou cmd à l'ouverture, pas un autre choix comme WSL
  $parDefaut = ''
  if ($pwshProfil -and (-not $d.defaultProfile -or $d.defaultProfile -in $WindowsPowerShell, $Cmd)) {
    Edit-Cle $d defaultProfile $pwshProfil.guid
    $parDefaut = ', PowerShell 7 par défaut'
  }

  $nouveau = $d | ConvertTo-Json -Depth 100
  if ($nouveau -ne $avant) {
    Save-Copie $fichier
    New-Item -ItemType Directory -Force (Split-Path $fichier) | Out-Null
    Set-Content -Path $fichier -Value $nouveau -Encoding utf8
  }
  $WtManuel = $false
  Write-Host "[ok] Windows Terminal : police $Police, couleurs Catppuccin Mocha sur PowerShell$parDefaut"
}

# ---------- Thème eza façon Material Icon Theme (VS Code) ----------
Write-Titre 'Thème eza'
Install-Config eza/theme.yml (Join-Path $env:APPDATA 'eza\theme.yml')

# ---------- Profil PowerShell ----------
Write-Titre 'Profil PowerShell'
$Profil = $PROFILE.CurrentUserCurrentHost
Install-Config config/profile.ps1 $Profil

# ---------- Starship (prompt deux lignes, Catppuccin Mocha) ----------
Write-Titre 'starship.toml'
Install-Config config/starship.toml (Join-Path $HOME '.config\starship.toml')

# ---------- lazygit, delta ----------
Write-Titre 'lazygit, delta'
if (Get-Command lazygit -ErrorAction Ignore) {
  $dossier = lazygit --print-config-dir 2>$null | Select-Object -First 1
  if (-not $dossier) {
    $dossier = Join-Path $env:LOCALAPPDATA 'lazygit'
  }
  Install-Config config/lazygit.yml (Join-Path $dossier 'config.yml')
}
if ((Get-Command delta -ErrorAction Ignore) -and (Get-Command git -ErrorAction Ignore)) {
  git config --global core.pager delta
  git config --global interactive.diffFilter 'delta --color-only'
  git config --global delta.navigate true
  git config --global delta.line-numbers true
  git config --global merge.conflictStyle zdiff3
} else {
  Write-Host "[..] delta ou git absent, config git inchangée"
}

# ---------- atuin, tldr ----------
Write-Titre 'atuin, tldr'
if (Get-Command atuin -ErrorAction Ignore) {
  # Dossier choisi par atuin lui-même : ~/.atuin pour une installation neuve, ~/.config/atuin sinon
  $config = Get-Capture (atuin info 2>$null) 'client config: "(.+)"'
  if ($config) {
    $config = $config -replace '\\\\', '\'
  } else {
    $config = Join-Path $HOME '.config\atuin\config.toml'
  }
  Install-Config config/atuin/config.toml $config
  Install-Config config/atuin/themes/catppuccin-mocha-mauve.toml (Join-Path (Split-Path $config) 'themes\catppuccin-mocha-mauve.toml')
  # Une seule fois, tant que la base d'atuin est vide : l'historique PowerShell existant y entre
  $historique = Join-Path $env:APPDATA 'Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt'
  $env:ATUIN_SESSION = atuin uuid
  $dejaRemplie = atuin search --limit 1 --cmd-only 2>$null
  if ((Test-Path $historique) -and (Get-Item $historique).Length -gt 0 -and -not $dejaRemplie) {
    atuin import powershell *> $null
    if ($LASTEXITCODE -eq 0) {
      Write-Host "[ok] historique PowerShell importé dans atuin"
    } else {
      Write-Host "[!!] import de l'historique dans atuin échoué"
    }
  }
  Remove-Item Env:ATUIN_SESSION -ErrorAction Ignore
}

if (Get-Command tldr -ErrorAction Ignore) {
  $chemins = tldr --show-paths 2>$null
  $config = Get-Capture $chemins '^Config path:\s+(.+) \('
  if ($config) {
    Install-Config config/tealdeer.toml $config
  } else {
    Write-Host "[!!] dossier de config de tldr introuvable, couleurs par défaut"
  }
  $pages = Get-Capture $chemins '^Pages dir:\s+(.+)$'
  if (-not $pages -or -not (Test-Path $pages)) {
    tldr --update *> $null
    if ($LASTEXITCODE -eq 0) {
      Write-Host "[ok] pages tldr téléchargées"
    } else {
      Write-Host "[..] pages tldr non téléchargées, elles le seront au premier tldr"
    }
  }
}

Write-Titre 'Terminé'
Write-Host "Ouvrir un nouvel onglet Windows Terminal : PowerShell 7 démarre avec le prompt et les outils."
if ($WtManuel) {
  Write-Host "Dans le terminal : police $Police et jeu de couleurs Catppuccin Mocha, à choisir dans ses paramètres."
}
Write-Host "À essayer : Ctrl+R cherche dans l'historique (atuin), Tab complète dans fzf, tldr tar donne des exemples."
$ProfilLocal = Join-Path (Split-Path $Profil) 'profile.local.ps1'
if (-not (Test-Path $ProfilLocal)) {
  Write-Host "Les alias et fonctions personnels vont dans $ProfilLocal : le script ne le touche jamais."
}
