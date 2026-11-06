# Stop the site started by tools\run.ps1.
param([switch]$Quiet)
$pidFile = Join-Path $PSScriptRoot 'site.pid'
$stopped = $false
if (Test-Path $pidFile) {
  $id = [int](Get-Content $pidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
  $p = Get-Process -Id $id -ErrorAction SilentlyContinue
  if ($p -and $p.ProcessName -eq 'MyfschoolHost') { Stop-Process -Id $id -Force; $stopped = $true }
  Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
}
# also kill stray hosts (e.g. pid file lost)
Get-Process -Name MyfschoolHost -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue; $stopped = $true }
if (-not $Quiet) { if ($stopped) { Write-Host 'Site stopped.' } else { Write-Host 'Site was not running.' } }
