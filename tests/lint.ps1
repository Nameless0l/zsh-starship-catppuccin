# PowerShell checks for tests/lint.sh: syntax, then PSScriptAnalyzer when installed.
$fails = 0
Set-Location (Split-Path -Parent $PSScriptRoot)
foreach ($f in Get-ChildItem setup-terminal-windows.ps1, config/*.ps1, tests/*.ps1) {
  $errors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errors)
  foreach ($e in $errors) { Write-Host "$($f.Name):$($e.Extent.StartLineNumber): $($e.Message)"; $fails++ }
}
if (Get-Module -ListAvailable PSScriptAnalyzer) {
  # No BOM in the scripts on purpose: it breaks irm | iex
  $excluded = 'PSAvoidUsingWriteHost', 'PSAvoidUsingInvokeExpression', 'PSUseBOMForUnicodeEncodedFile'
  $issues = Get-ChildItem setup-terminal-windows.ps1, config/*.ps1, tests/*.ps1 |
    ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Warning, Error -ExcludeRule $excluded }
  foreach ($i in $issues) { Write-Host "$($i.ScriptName):$($i.Line): $($i.RuleName): $($i.Message)"; $fails++ }
} else {
  Write-Host "PSScriptAnalyzer missing, PowerShell syntax only"
}
exit $fails
