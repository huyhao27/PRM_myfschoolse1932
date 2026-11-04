@echo off
chcp 65001 >nul
title MyFSchool - Web quan ly
echo ======================================================================
echo    MYFSCHOOL - WEB QUAN LY (Truong THPT FPT Ha Noi)
echo ======================================================================
echo Dang build va khoi dong site tai http://localhost:8088 ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run.ps1"
if errorlevel 1 (
    echo [LOI] Khong khoi dong duoc. Xem tools\site.log
    pause
    exit /b 1
)
start http://localhost:8088/Login.aspx
echo.
echo Site dang chay nen. De dung: tools\stop.ps1
pause
