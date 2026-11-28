# Profil PowerShell 7, équivalent du ~/.zshrc des scripts Linux
# Alias, fonctions et variables perso : profile.local.ps1 à côté de ce fichier, jamais écrasé par le script

# ==================== Alias et fonctions ====================
if (Get-Command eza -ErrorAction Ignore) {
  Remove-Item Alias:ls -Force -ErrorAction Ignore
  function ls { eza --icons --group-directories-first @args }
  function ll { eza -l --icons --git --group-directories-first @args }
  function la { eza -la --icons --git --group-directories-first @args }
  function lt { eza --tree --level=2 --icons --git-ignore @args }
}
if (Get-Command bat -ErrorAction Ignore) {
  Remove-Item Alias:cat -Force -ErrorAction Ignore
  function cat { bat --paging=never @args }
}
if (Get-Command lazygit -ErrorAction Ignore) {
  Set-Alias lg lazygit
}

# ==================== Outils ====================
$env:BAT_THEME = 'ansi'

# fzf : Ctrl+T fichier avec aperçu, Alt+C dossier avec arbre (et Ctrl+R si atuin manque)
$env:FZF_DEFAULT_OPTS = '--border=rounded --color=bg+:#313244,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8'
$env:FZF_CTRL_T_OPTS = "--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
$env:FZF_ALT_C_OPTS = "--preview 'eza --tree --level=2 --icons --color=always {}'"
if (Get-Command fd -ErrorAction Ignore) {
  # fd respecte le .gitignore : target/, build/ et .git restent hors des résultats
  $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow --exclude .git'
  $env:FZF_CTRL_T_COMMAND = $env:FZF_DEFAULT_COMMAND
  $env:FZF_ALT_C_COMMAND = 'fd --type d --hidden --follow --exclude .git'
}

# zoxide remplace cd : "cd morceau" saute dans un dossier déjà visité, "cdi" pour choisir avec fzf
if (Get-Command zoxide -ErrorAction Ignore) {
  Invoke-Expression (& { (zoxide init powershell --cmd cd | Out-String) })
}

# ==================== Prompt ====================
if (Get-Command starship -ErrorAction Ignore) {
  Invoke-Expression (& starship init powershell)
}

# ==================== Ligne de commande ====================
# PSReadLine n'est chargé que dans un terminal interactif
if (Get-Module PSReadLine) {
  # Suggestions grisées tirées de l'historique (→ pour accepter), couleurs Catppuccin Mocha
  if (-not [Console]::IsOutputRedirected) {
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView
  }
  Set-PSReadLineOption -MaximumHistoryCount 100000 -HistoryNoDuplicates -HistorySearchCursorMovesToEnd
  Set-PSReadLineOption -Colors @{
    Command                = '#89b4fa'
    Comment                = '#6c7086'
    ContinuationPrompt     = '#94e2d5'
    Default                = '#cdd6f4'
    Emphasis               = '#f38ba8'
    Error                  = '#f38ba8'
    InlinePrediction       = '#6c7086'
    Keyword                = '#cba6f7'
    ListPrediction         = '#cba6f7'
    ListPredictionSelected = "`e[48;2;49;50;68m"
    Member                 = '#f5e0dc'
    Number                 = '#fab387'
    Operator               = '#89dceb'
    Parameter              = '#f5c2e7'
    Selection              = "`e[48;2;69;71;90m"
    String                 = '#a6e3a1'
    Type                   = '#f9e2af'
    Variable               = '#b4befe'
  }
  # " commande" n'est pas enregistrée
  Set-PSReadLineOption -AddToHistoryHandler {
    param($ligne)
    if ($ligne.StartsWith(' ')) { return $false }
    [Microsoft.PowerShell.PSConsoleReadLine]::GetDefaultAddToHistoryOption($ligne)
  }

  # Ctrl+→ prend aussi le mot suivant de la suggestion grisée
  Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
  # ↑ et ↓ ne parcourent que les commandes qui commencent comme la ligne tapée
  Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
  Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
  # Ctrl+X puis Ctrl+E : éditer la commande dans l'éditeur ($env:EDITOR)
  Set-PSReadLineKeyHandler -Chord 'Ctrl+x,Ctrl+e' -Function ViEditVisually

  # PSFzf : Tab ouvre les complétions dans fzf, Ctrl+T et Alt+C avec leur aperçu
  # L'aperçu de Tab échoue sous Windows (github.com/kelleyma49/PSFzf/issues/380) : il reste masqué
  if (Get-Module -ListAvailable PSFzf) {
    $raccourcis = @{ PSReadlineChordProvider = 'Ctrl+t'; PSReadlineChordSetLocation = 'Alt+c' }
    if (-not (Get-Command atuin -ErrorAction Ignore)) {
      $raccourcis.PSReadlineChordReverseHistory = 'Ctrl+r'
    }
    Import-Module PSFzf
    Set-PsFzfOption @raccourcis -TabCompletionPreviewWindow 'hidden|hidden'
    Set-PSReadLineKeyHandler -Key Tab -BriefDescription FzfTabCompletion -Description 'Complétion dans fzf' -ScriptBlock { Invoke-FzfTabCompletion }
    Remove-Variable raccourcis
  }

  # atuin : historique dans une base, Ctrl+R pour chercher dedans (↑ garde la recherche par préfixe)
  if (Get-Command atuin -ErrorAction Ignore) {
    atuin init powershell --disable-up-arrow | Out-String | Invoke-Expression
  }

  # Prompt transitoire : une fois la commande validée, il ne reste que ❯
  if (Get-Command Enable-TransientPrompt -ErrorAction Ignore) {
    function Invoke-Starship-TransientFunction { & starship module character }
    Enable-TransientPrompt
  }
}

# ==================== Réglages propres à la machine ====================
$profilLocal = Join-Path $PSScriptRoot 'profile.local.ps1'
if (Test-Path $profilLocal) { . $profilLocal }
Remove-Variable profilLocal -ErrorAction Ignore
