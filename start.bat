@echo off
rem Double-click to run everything: database, backend (new window) and the Flutter app in Chrome.
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\setup-backend.ps1"
if errorlevel 1 (
  echo.
  echo Setup failed, see the message above.
  pause
  exit /b 1
)

start "MyFSchool backend" cmd /k "cd /d %~dp0backend && npm start"

echo Waiting for the backend to answer...
powershell -NoProfile -Command "for($i=0;$i -lt 30;$i++){ try { Invoke-RestMethod http://127.0.0.1:3000/api/health -TimeoutSec 3 | Out-Null; exit 0 } catch { Start-Sleep 1 } }; exit 1"
if errorlevel 1 (
  echo The backend did not start. Look at the "MyFSchool backend" window for the error.
  pause
  exit /b 1
)

call flutter pub get
call flutter run -d chrome
