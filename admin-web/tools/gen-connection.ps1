# Generates connections.config (ignored by git) from the repo's backend\.env (admin-web sits next to backend\).
# Usage: powershell -ExecutionPolicy Bypass -File tools\gen-connection.ps1 [-EnvFile <path to backend\.env>]
param([string]$EnvFile)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $EnvFile) { $EnvFile = Join-Path $root '..\backend\.env' }
if (-not (Test-Path $EnvFile)) { Write-Error "Cannot find $EnvFile - pass -EnvFile <path>"; exit 1 }
$e = @{}
Get-Content $EnvFile -Encoding UTF8 | ForEach-Object {
  if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') { $e[$Matches[1]] = $Matches[2].Trim('"').Trim("'") }
}
foreach ($k in 'DB_SERVER','DB_USER','DB_PASSWORD') { if (-not $e[$k]) { Write-Error "$k missing in $EnvFile"; exit 1 } }
$port = if ($e['DB_PORT']) { $e['DB_PORT'] } else { '1433' }
$db   = if ($e['DB_NAME']) { $e['DB_NAME'] } else { 'FSchoolDB' }
$cs = "Server=$($e['DB_SERVER']),$port;Database=$db;User Id=$($e['DB_USER']);Password=$($e['DB_PASSWORD']);Encrypt=False;TrustServerCertificate=True;Connect Timeout=10"
$cs = [System.Security.SecurityElement]::Escape($cs)
$xml = "<?xml version=`"1.0`" encoding=`"utf-8`"?>`r`n<connectionStrings>`r`n  <add name=`"FSchoolDb`" connectionString=`"$cs`" providerName=`"System.Data.SqlClient`" />`r`n</connectionStrings>`r`n"
[System.IO.File]::WriteAllText((Join-Path $root 'connections.config'), $xml, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "connections.config written (server $($e['DB_SERVER']),$port database $db). Do not commit it."
