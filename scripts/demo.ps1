# Prepares everything for a live demo: SQL Server + FSchoolDB, the C# web (http://localhost:8088, also the app's API /api/m),
# the Flutter app on http://localhost:8090, then opens both in the browser.
# Usage: scripts\demo.ps1 [-Reset] [-NoReset] [-BaseOnly] [-NoBrowser]
#   -Reset     put the demo data back to its original state without asking (deletes everything else in FSchoolDB)
#   -NoReset   keep the current data without asking
#   -BaseOnly  do not add backend\sql\demo-extra.sql (only the 6 base accounts and their data)
param([switch]$Reset, [switch]$NoReset, [switch]$BaseOnly, [switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$web = Join-Path $root 'admin-web'
$appUrl = 'http://localhost:8090'
$webUrl = 'http://localhost:8088'

function Step($t) { Write-Host ''; Write-Host "==> $t" -ForegroundColor Cyan }
function Fail($t) { Write-Host ''; Write-Host "LỖI: $t" -ForegroundColor Red; exit 1 }
function WaitUrl($url, $seconds) {
  for ($i = 0; $i -lt $seconds; $i++) {
    try { Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 30 | Out-Null; return $true } catch { Start-Sleep 1 }
  }
  return $false
}

# 1. Database: starts SQL Server if needed, creates FSchoolDB, tables and demo data (idempotent).
Step '1/5 SQL Server + database FSchoolDB'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'setup-backend.ps1')
if ($LASTEXITCODE -ne 0) { Fail 'Không dựng được database (xem thông báo phía trên).' }

# 2. Optional: back to the original demo data (base seed, then the extra data below).
if (-not $Reset -and -not $NoReset) {
  $a = Read-Host 'Đưa dữ liệu về trạng thái mẫu ban đầu? Mọi thay đổi khi thử sẽ mất. [y/N]'
  $Reset = $a -match '^(y|yes|c|co|có)$'
}
if ($Reset) {
  Step '2/5 Đưa dữ liệu mẫu về ban đầu'
  & sqlcmd -S 'localhost,1433' -E -C -b -I -d FSchoolDB -i (Join-Path $PSScriptRoot 'reset-demo-data.sql')
  if ($LASTEXITCODE -ne 0) { Fail 'Không xoá được dữ liệu cũ.' }
  Push-Location (Join-Path $root 'backend')
  try { & npm run db:init; if ($LASTEXITCODE -ne 0) { Fail 'npm run db:init lỗi.' } } finally { Pop-Location }
} else { Step '2/5 Giữ nguyên dữ liệu hiện có' }

# Extra demo data (6 teachers, 34 students in 10A1/10A2/11A1, parents, timetables, grades, requests, clubs).
# Runs once: the script skips itself when the data is already there. -BaseOnly keeps only the base seed (used by tests).
if (-not $BaseOnly) {
  Write-Host 'Nạp dữ liệu demo bổ sung (backend\sql\demo-extra.sql)...'
  & sqlcmd -S 'localhost,1433' -E -C -b -I -f 65001 -d FSchoolDB -i (Join-Path $root 'backend\sql\demo-extra.sql')
  if ($LASTEXITCODE -ne 0) { Fail 'Không nạp được dữ liệu demo bổ sung.' }
}

# 3. Web (build + self-host). A fresh start also clears the in-memory login rate limiter.
Step '3/5 Build và chạy web C# (cổng 8088)'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $web 'tools\run.ps1')
if ($LASTEXITCODE -ne 0) { Fail "Web không chạy được, xem $web\tools\site.log" }
if (-not (WaitUrl "$webUrl/api/m/health" 60)) { Fail "$webUrl/api/m/health không trả lời." }
Write-Host 'Làm nóng các trang (lần đầu ASP.NET biên dịch trang mất khoảng 30 giây)...'
foreach ($p in 'Login.aspx', 'api/m/health') { WaitUrl "$webUrl/$p" 90 | Out-Null }

# 4. Flutter app on a fixed port, in its own window (close that window to stop the app).
#    --release: debug mode on web-server waits for a debugger to attach and shows a blank page.
Step '4/5 Chạy app Flutter (cổng 8090, cửa sổ riêng)'
$busy = Get-NetTCPConnection -LocalPort 8090 -State Listen -ErrorAction SilentlyContinue
if ($busy) {
  Write-Host 'App đã chạy sẵn ở cổng 8090, dùng tiếp.'
} else {
  if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { Fail 'Không tìm thấy lệnh flutter trong PATH.' }
  Start-Process -FilePath 'cmd.exe' -WorkingDirectory $root -ArgumentList '/k', 'title MyFSchool app (Flutter) && flutter pub get && flutter run -d web-server --web-port=8090 --web-hostname=localhost --release'
  Write-Host 'Đang biên dịch app (lần đầu có thể mất 1-2 phút)...'
  if (-not (WaitUrl $appUrl 300)) { Fail 'App chưa lên ở cổng 8090, xem cửa sổ "MyFSchool app (Flutter)".' }
}

# 5. Open the browser and print the cheat sheet.
Step '5/5 Sẵn sàng'
if (-not $NoBrowser) { Start-Process $appUrl; Start-Process "$webUrl/Login.aspx" }
Write-Host ''
Write-Host "  App Flutter : $appUrl" -ForegroundColor Green
Write-Host "  Web quản trị: $webUrl/Login.aspx" -ForegroundColor Green
Write-Host "  API cho app : $webUrl/api/m/health" -ForegroundColor Green
Write-Host ''
Write-Host '  Tài khoản (mật khẩu 123456)   SĐT'
Write-Host '  Phụ huynh (2 con)            0901234567   app'
Write-Host '  Học sinh                     0901000003   app'
Write-Host '  Giáo viên                    0901000001   app + web'
Write-Host '  Quản lý                      0901000002   app + web'
if (-not $BaseOnly) {
  Write-Host '  Dữ liệu bổ sung: lớp 10A1, 10A2, 11A1 (34 học sinh), 6 giáo viên, 31 phụ huynh'
  Write-Host '  GV Nguyễn Thị Hương (Toán)   0902000001   dạy 10A2 + 11A1'
  Write-Host '  PH có con ở 10A1 và 10A2     0904000001'
  Write-Host '  HS lớp 10A2                  0903000011 ... 0903000022'
}
Write-Host ''
Write-Host '  Tắt tất cả: demo-stop.bat'
