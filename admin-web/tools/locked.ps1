# Runs ONE tools script under a machine-wide lock so several people/agents never build or host the site at the same time
# (the build overwrites bin\MyfschoolWeb.dll, which the running site keeps open).
# Usage: powershell -ExecutionPolicy Bypass -File tools\locked.ps1 -Cmd "run.ps1; smoke.ps1"
#   -Cmd is a ';'-separated list of scripts inside tools\ (arguments allowed, e.g. "run.ps1 -NoBuild").
# Standard test cycle: -Cmd "run.ps1; smoke.ps1; stop.ps1"   (always ends with the site stopped, even on failure).
#   Add -KeepRunning to skip the final stop (use when you want to look at the site in a browser afterwards;
#   the next agent's locked run restarts it anyway).
param([Parameter(Mandatory)][string]$Cmd, [int]$WaitMinutes = 20, [switch]$KeepRunning)
$m = New-Object System.Threading.Mutex($false, 'Global\MyfschoolWebBuildLock')
Write-Host "Waiting for the build lock..."
if (-not $m.WaitOne([TimeSpan]::FromMinutes($WaitMinutes))) { Write-Host "Could not get the lock in $WaitMinutes minutes" -ForegroundColor Red; exit 2 }
$code = 0
try {
  Write-Host "Lock acquired."
  foreach ($c in ($Cmd -split ';')) {
    $c = $c.Trim(); if (-not $c) { continue }
    $parts = $c -split '\s+'
    $LASTEXITCODE = 0
    $scriptArgs = @($parts | Select-Object -Skip 1)
    & (Join-Path $PSScriptRoot $parts[0]) @scriptArgs 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) { $code = $LASTEXITCODE; Write-Host "FAILED: $c (exit $code)" -ForegroundColor Red; break }
  }
} finally {
  if (-not $KeepRunning) { & "$PSScriptRoot\stop.ps1" -Quiet 2>$null }
  $m.ReleaseMutex()
}
exit $code
