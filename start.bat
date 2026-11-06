@echo off
rem Double-click to run everything: database, the C# web service (admin-web, http://localhost:8088) and the Flutter app in Chrome.
cd /d "%~dp0"

rem Database: schema + demo data (Node is only used here as a DB tool).
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\setup-backend.ps1"
if errorlevel 1 (
  echo.
  echo Setup failed, see the message above.
  pause
  exit /b 1
)

rem The C# portal is the backend of the app (JSON under /api/m). run.ps1 builds it and starts it in the background.
if not exist "admin-web\connections.config" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "admin-web	ools\gen-connection.ps1"
)
powershell -NoProfile -ExecutionPolicy Bypass -File "admin-web	oolsun.ps1"
if errorlevel 1 (
  echo The portal did not start. See admin-web	ools\site.log
  pause
  exit /b 1
)

echo Waiting for the web service to answer...
powershell -NoProfile -Command "$u='http://localhost:8088/api/m/health'; for($i=0;$i -lt 90;$i++){ try { Invoke-RestMethod $u -TimeoutSec 3 | Out-Null; exit 0 } catch { Start-Sleep 1 } }; Write-Host ('No answer from ' + $u); exit 1"
if errorlevel 1 (
  echo The web service did not answer. See admin-web	ools\site.log (stop it with admin-web	ools\stop.ps1).
  pause
  exit /b 1
)

call flutter pub get
call flutter run -d chrome
