# Prepares everything the backend needs. Safe to run any number of times.
#   1. checks Node and SQL Server
#   2. creates backend/.env (random password + JWT secret) if missing
#   3. starts the SQL Server service (asks for admin once) and sets it to start with Windows
#   4. creates the database and the app login if missing
#   5. npm install, then creates tables and demo users (npm run db:init)
param(
  [string]$EnvPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'backend\.env')
)
# Native tools (sqlcmd, npm) report failure through exit codes that we check ourselves.
# 'Stop' would turn any stderr line of a probe into a terminating error in Windows PowerShell 5.1.
$ErrorActionPreference = 'Continue'
$backend = Join-Path (Split-Path $PSScriptRoot -Parent) 'backend'

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }
function RandomText($len) {
  -join ((48..57) + (65..90) + (97..122) | Get-Random -Count $len | ForEach-Object { [char]$_ })
}

# 1. tools ---------------------------------------------------------------
Step 'Checking Node.js'
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Fail 'Node.js is not installed. Install Node 22 from https://nodejs.org and run again.' }
Step 'Checking sqlcmd'
$sqlcmd = (Get-Command sqlcmd -ErrorAction SilentlyContinue).Source
if (-not $sqlcmd) { Fail 'sqlcmd is not installed (comes with SQL Server / SQL Server command line tools).' }

# 2. .env ----------------------------------------------------------------
if (-not (Test-Path $EnvPath)) {
  Step "Creating $EnvPath"
  $example = Join-Path $backend '.env.example'
  $text = (Get-Content $example -Raw)
  $text = $text -replace 'DB_USER=.*', 'DB_USER=fschool_app'
  $text = $text -replace 'DB_PASSWORD=.*', ('DB_PASSWORD=Fs!' + (RandomText 14))
  $text = $text -replace 'JWT_SECRET=.*', ('JWT_SECRET=' + (RandomText 48))
  Set-Content -Path $EnvPath -Value $text -Encoding ascii
}
$cfg = @{}
Get-Content $EnvPath | ForEach-Object {
  if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') { $cfg[$Matches[1]] = $Matches[2] }
}
foreach ($k in 'DB_SERVER', 'DB_PORT', 'DB_NAME', 'DB_USER', 'DB_PASSWORD') {
  if (-not $cfg[$k]) { Fail "$k is missing in $EnvPath" }
}
# npm/node read these first (dotenv never overrides existing variables)
foreach ($k in $cfg.Keys) { Set-Item -Path "env:$k" -Value $cfg[$k] }
$server = "$($cfg.DB_SERVER),$($cfg.DB_PORT)"
$db = $cfg.DB_NAME
$user = $cfg.DB_USER
$pw = $cfg.DB_PASSWORD
if ($db -notmatch '^[A-Za-z0-9_]+$' -or $user -notmatch '^[A-Za-z0-9_]+$') { Fail 'DB_NAME and DB_USER may only contain letters, digits and underscore.' }
$pwSql = $pw.Replace("'", "''")

# 3. SQL Server service --------------------------------------------------
Step 'Checking SQL Server service'
$svc = Get-Service MSSQLSERVER -ErrorAction SilentlyContinue
if (-not $svc) { Fail 'SQL Server (service MSSQLSERVER) is not installed on this machine.' }
if ($svc.Status -ne 'Running') {
  Write-Host 'SQL Server is stopped. Starting it (a Windows admin prompt may appear)...'
  $cmd = 'Set-Service MSSQLSERVER -StartupType Automatic; Start-Service MSSQLSERVER'
  Start-Process powershell -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList '-NoProfile', '-Command', $cmd
  $svc.Refresh()
  if ((Get-Service MSSQLSERVER).Status -ne 'Running') { Fail 'Could not start SQL Server. Open PowerShell as Administrator and run: Start-Service MSSQLSERVER' }
}
# the service can be "Running" a few seconds before it accepts connections
$ready = $false
foreach ($i in 1..30) {
  & $sqlcmd -S $server -E -C -b -Q 'SELECT 1' *> $null
  if ($LASTEXITCODE -eq 0) { $ready = $true; break }
  Start-Sleep 2
}
if (-not $ready) { Fail "SQL Server does not accept connections on $server (check TCP/IP is enabled in SQL Server Configuration Manager)." }

# 4. database + login ----------------------------------------------------
Step "Checking database $db and login $user"
& $sqlcmd -S $server -U $user -P $pw -d $db -C -b -Q 'SELECT 1' *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Creating database and login (using your Windows account)...'
  $admin = @(
    "IF DB_ID('$db') IS NULL CREATE DATABASE [$db];",
    "IF SUSER_ID('$user') IS NULL CREATE LOGIN [$user] WITH PASSWORD='$pwSql', CHECK_POLICY=OFF; ALTER LOGIN [$user] WITH PASSWORD='$pwSql';"
  )
  foreach ($q in $admin) {
    & $sqlcmd -S $server -E -C -b -Q $q
    if ($LASTEXITCODE -ne 0) { Fail 'Could not create the database/login. Your Windows account needs sysadmin rights on this SQL Server.' }
  }
  & $sqlcmd -S $server -E -C -b -d $db -Q "IF USER_ID('$user') IS NULL CREATE USER [$user] FOR LOGIN [$user]; ALTER ROLE db_owner ADD MEMBER [$user];"
  if ($LASTEXITCODE -ne 0) { Fail 'Could not grant the login access to the database.' }
  & $sqlcmd -S $server -U $user -P $pw -d $db -C -b -Q 'SELECT 1' *> $null
  if ($LASTEXITCODE -ne 0) { Fail 'The new login cannot connect. SQL Server must allow SQL logins (mixed mode authentication).' }
}

# 5. packages, tables, demo users ----------------------------------------
Push-Location $backend
try {
  if (-not (Test-Path 'node_modules')) {
    Step 'Installing npm packages'
    npm install --no-audit --no-fund
    if ($LASTEXITCODE -ne 0) { Fail 'npm install failed.' }
  }
  Step 'Creating tables and demo users'
  npm run db:init
  if ($LASTEXITCODE -ne 0) { Fail 'db:init failed.' }
} finally {
  Pop-Location
}

Write-Host ''
Write-Host 'Backend is ready. Demo accounts (password 123456): gv@fschool.vn, manager@fschool.vn, ph@fschool.vn, hs@fschool.vn' -ForegroundColor Green
