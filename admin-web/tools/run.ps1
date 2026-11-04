# Start MyFSchool web on http://localhost:8088 in the background (self-host, no IIS). Writes tools\site.pid.
# Usage: powershell -ExecutionPolicy Bypass -File tools\run.ps1 [-Port 8088] [-NoBuild]
param([int]$Port = 8088, [switch]$NoBuild)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$pidFile = Join-Path $PSScriptRoot 'site.pid'
$log = Join-Path $PSScriptRoot 'site.log'

& (Join-Path $PSScriptRoot 'stop.ps1') -Quiet
if (-not (Test-Path "$root\connections.config")) { & (Join-Path $PSScriptRoot 'gen-connection.ps1') }
if (-not $NoBuild) { & (Join-Path $PSScriptRoot 'build.ps1'); if ($LASTEXITCODE -ne 0) { exit 1 } }
if (-not (Test-Path "$root\bin\MyfschoolHost.exe")) { Write-Error "bin\MyfschoolHost.exe missing - run tools\build.ps1"; exit 1 }

$p = Start-Process -FilePath "$root\bin\MyfschoolHost.exe" -ArgumentList "`"$root`"", $Port -WindowStyle Hidden -PassThru `
      -RedirectStandardOutput $log -RedirectStandardError "$log.err"
Set-Content $pidFile $p.Id

$url = "http://localhost:$Port/Login.aspx"
$ok = $false
for ($i = 0; $i -lt 60; $i++) {
  Start-Sleep -Milliseconds 500
  if ($p.HasExited) { break }
  try { $r = Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 30; if ($r.StatusCode -eq 200) { $ok = $true; break } } catch { }
}
if ($ok) { Write-Host "Site running (pid $($p.Id)): http://localhost:$Port/" -ForegroundColor Green; exit 0 }
Write-Host "Site did not answer on $url" -ForegroundColor Red
Get-Content $log, "$log.err" -ErrorAction SilentlyContinue | Select-Object -First 30 | ForEach-Object { Write-Host "  $_" }
& (Join-Path $PSScriptRoot 'stop.ps1') -Quiet
exit 1
