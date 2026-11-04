# Compile every .cs of the web project into bin\MyfschoolWeb.dll (Roslyn csc from VS BuildTools; no MSBuild web targets needed)
# and compile the self-host launcher tools\MyfschoolHost.cs into bin\MyfschoolHost.exe.
# Usage: powershell -ExecutionPolicy Bypass -File tools\build.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# --- locate Roslyn csc (C# 6+ is required by the code base) ---
$cands = @(
  "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\Roslyn\csc.exe",
  "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\Roslyn\csc.exe",
  "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\Roslyn\csc.exe",
  "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\Roslyn\csc.exe",
  "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\Roslyn\csc.exe")
$csc = $cands | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $csc) { Write-Error "Roslyn csc.exe not found (install VS Build Tools 2022)."; exit 1 }
$fw = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()

# --- make sure BCrypt is in bin ---
$bcSrc = Join-Path $root 'packages\BCrypt.Net-Next.4.0.3\lib\net48\BCrypt.Net-Next.dll'
if (-not (Test-Path "$root\bin\BCrypt.Net-Next.dll") -and (Test-Path $bcSrc)) { Copy-Item $bcSrc "$root\bin\" }

# --- sources ---
$exclude = '\\(obj|bin|packages|tools|\.vs|Scripts)\\'
$sources = Get-ChildItem $root -Recurse -Filter *.cs | Where-Object { $_.FullName -notmatch $exclude } | ForEach-Object { $_.FullName }

# --- references: framework + every managed dll in bin (except our own) ---
$refs = New-Object System.Collections.Generic.List[string]
foreach ($n in 'System','System.Core','System.Data','System.Web','System.Xml','System.Xml.Linq','System.Configuration','System.Drawing','System.Net.Http','System.Web.Services','System.EnterpriseServices','System.IO.Compression','System.ComponentModel.Composition','System.Numerics','Microsoft.CSharp') {
  $refs.Add("/r:`"$fw$n.dll`"")
}
Get-ChildItem "$root\bin\*.dll" | Where-Object { $_.Name -ne 'MyfschoolWeb.dll' } | ForEach-Object {
  try { [void][System.Reflection.AssemblyName]::GetAssemblyName($_.FullName); $refs.Add("/r:`"$($_.FullName)`"") } catch { }   # skips native dlls
}

$rsp = Join-Path $env:TEMP 'myfschool-web-build.rsp'
$outArg = '/out:"' + (Join-Path $root 'bin\MyfschoolWeb.dll') + '"'
$lines = @('/nologo','/target:library','/debug:full','/langversion:latest','/utf8output','/codepage:65001','/nowarn:1591,0618,0168,0219',$outArg)
$lines += $refs
$lines += ($sources | ForEach-Object { '"' + $_ + '"' })
[System.IO.File]::WriteAllLines($rsp, $lines, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Compiling $($sources.Count) files -> bin\MyfschoolWeb.dll"
$out = & $csc "@$rsp" 2>&1
$code = $LASTEXITCODE
$errs = @($out | Where-Object { "$_" -match ': error ' })
if ($code -ne 0 -or $errs.Count -gt 0) {
  Write-Host "BUILD FAILED ($($errs.Count) error(s))" -ForegroundColor Red
  $errs | ForEach-Object { Write-Host ("  " + ("$_" -replace [regex]::Escape($root + '\'), '')) -ForegroundColor Red }
  if ($errs.Count -eq 0) { $out | ForEach-Object { Write-Host "  $_" } }
  exit 1
}
$warn = @($out | Where-Object { "$_" -match ': warning ' }).Count
Write-Host "Web build OK ($warn warning(s))" -ForegroundColor Green

# --- self-host launcher ---
$hostSrc = Join-Path $PSScriptRoot 'MyfschoolHost.cs'
$hostOut = Join-Path $root 'bin\MyfschoolHost.exe'
$needHost = (-not (Test-Path $hostOut)) -or ((Get-Item $hostSrc).LastWriteTime -gt (Get-Item $hostOut).LastWriteTime)
if ($needHost) {
  $hout = & $csc /nologo /target:exe /utf8output "/r:$($fw)System.dll" "/r:$($fw)System.Web.dll" "/out:$hostOut" $hostSrc 2>&1
  if ($LASTEXITCODE -ne 0) { Write-Host "HOST BUILD FAILED" -ForegroundColor Red; $hout | ForEach-Object { Write-Host "  $_" }; exit 1 }
  Write-Host "Host build OK -> bin\MyfschoolHost.exe" -ForegroundColor Green
}
exit 0
