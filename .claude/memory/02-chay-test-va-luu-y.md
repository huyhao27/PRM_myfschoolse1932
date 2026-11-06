# 02. Chạy, test và lưu ý

## Dựng môi trường và chạy (Windows, PowerShell)
Yêu cầu: Node 22, Flutter, SQL Server (service `MSSQLSERVER`, bật TCP 1433 và đăng nhập SQL), `sqlcmd`, VS Build Tools 2022 (để biên dịch web bằng Roslyn). Máy này KHÔNG có IIS/IIS Express.
```powershell
# 1. SQL Server + DB + bảng + dữ liệu mẫu (bật service, có thể hiện hộp thoại quyền Admin). Chạy lại bao nhiêu lần cũng được.
cd D:\Ki8\PRM\Project\myfschoolse1932
powershell -ExecutionPolicy Bypass -File scripts\setup-backend.ps1

# 2. Web C# = backend của app (http://localhost:8088). Lần mở đầu chậm ~30 giây vì biên dịch trang.
powershell -ExecutionPolicy Bypass -File admin-web\tools\run.ps1      # dừng: admin-web\tools\stop.ps1

# 3. App Flutter trên trình duyệt (cổng cố định để mở bằng công cụ trình duyệt)
flutter run -d web-server --web-port=8090      # hoặc flutter run -d chrome ; Android Studio: máy ảo Pixel_10_Pro dùng 10.0.2.2:8088
```
`start.bat` làm cả ba bước (app chạy Chrome, debug). Cho buổi demo dùng `demo.bat` (script `scripts/demo.ps1`): DB, hỏi reset dữ liệu mẫu (`scripts/reset-demo-data.sql` xoá sạch FSchoolDB rồi `db:init`), web, app Flutter `--release` cổng 8090 ở cửa sổ riêng, mở trình duyệt; tắt bằng `demo-stop.bat`. Lưu ý: `flutter run -d web-server` ở chế độ debug chỉ hiện trang trắng vì chờ debugger, nên phải `--release`. Địa chỉ: app http://localhost:8090, web http://localhost:8088/Login.aspx (dùng `localhost`, không dùng 127.0.0.1), health `http://localhost:8088/api/m/health`.
Đăng nhập thử (mật khẩu `123456`): app theo SĐT 0901234567 PH, 0901000003 HS, 0901000001 GV, 0901000002 Manager. Web chỉ Manager/GV.
Tệp cấu hình sinh tự động và KHÔNG commit: `backend/.env` (mật khẩu DB ngẫu nhiên, JWT_SECRET), `admin-web/connections.config`, `admin-web/secrets.config` (sinh bởi `admin-web/tools/gen-connection.ps1`, `run.ps1` tự gọi nếu thiếu).

## Kiểm thử (tiêu chí "xanh" hiện tại)
| Lệnh | Kết quả mong đợi |
|---|---|
| `flutter analyze` | không có lỗi |
| `flutter test` | 76 test đạt |
| `cd backend && npm test` (web C# phải đang chạy; mặc định API_BASE=http://localhost:8088, API_PREFIX=/api/m; Git Bash thêm `MSYS_NO_PATHCONV=1`) | 68 đạt |
| smoke web (PowerShell, trong `admin-web`): `tools\smoke.ps1`, `smoke-ui.ps1`, `smoke-grades.ps1`, `smoke-requests.ps1`, `smoke-students.ps1`, `smoke-mobile.ps1` | tất cả "OK" |
Chạy smoke có khoá: `tools\locked.ps1 -Cmd "run.ps1; smoke.ps1; stop.ps1"` (thêm `-KeepRunning` để giữ site chạy). `locked.ps1` dùng mutex vì build ghi đè `bin\MyfschoolWeb.dll` mà site đang mở; nhiều agent/người không được build/chạy cùng lúc.
Giới hạn tốc độ đăng nhập/reset là trong bộ nhớ: chạy bộ test Node vào C# hơn hai lần trong 15 phút có thể bị 429 đến khi khởi động lại site.

## Bất biến dữ liệu mẫu (test tự động dựa vào)
Từ 06/11/2026 `demo.bat` nạp thêm `backend/sql/demo-extra.sql` (sinh tự động, chạy một lần, cần `sqlcmd -I -f 65001`): +6 GV (0902000001-06), +34 HS (hs101-134, 0903000001-34, lớp 10A1/10A2/11A1), +31 PH (0904000001-31; 0904000001 có 2 con), TKB 10A2 + 11A1 (58 tiết), điểm HK1, 18 đơn (6 chờ), 33 thành viên CLB (không có ai approved ở Lập trình). Tổng sau khi nạp: 77 user, 87 tiết, 1728 điểm, 22 đơn (8 chờ), 35 ClubMembers (16 approved). Test và smoke vẫn xanh với dữ liệu này: chúng chỉ dựa vào 6 tài khoản gốc, 29 tiết 10A1, 5 CLB, Lập trình = 56; smoke-requests/students đã đổi sang so với số đếm lúc bắt đầu, và smoke-requests chỉ bấm dòng "Hoc sinh Mai" trong trang CLB.
Dữ liệu gốc dưới đây:
6 user, 29 tiết, 96 điểm, 4 đơn (2 chờ duyệt, NULL ý kiến), 5 CLB (Lập trình 56 thành viên), 2 dòng ClubMembers (hs: Bóng đá approved, Âm nhạc pending). Test/ smoke tự dọn dữ liệu của chúng; nếu thử tay thì dọn bằng (thêm `-I` khi xoá bảng Users):
```
sqlcmd -S localhost,1433 -E -C -d FSchoolDB -I -Q "DELETE FROM dbo.Requests WHERE reason LIKE 'TEST-%'"
sqlcmd ... -Q "UPDATE dbo.Requests SET status='pending',teacherComment=NULL,handledBy=NULL,handledAt=NULL WHERE reason LIKE N'Con bị sốt%' OR reason LIKE N'Con có lịch khám răng%'"
```
`npm run db:init` (hoặc `setup-backend.ps1`) tạo lại phần thiếu nhưng KHÔNG đặt lại mật khẩu đã đổi.

## Bẫy đã gặp
- `locked.ps1 ... -KeepRunning` mà pipe output (`| Select-String`) sẽ treo vì server nền giữ ống: ghi ra file (`Start-Process -RedirectStandardOutput`).
- Script .ps1 có tiếng Việt phải lưu UTF-8 **có BOM**, nếu không PowerShell 5.1 báo lỗi cú pháp (đã sửa smoke-ui, smoke-mobile).
- SQL Server tự tắt giữa chừng nhiều lần: chạy lại `setup-backend.ps1` là bật lại.
- Biên dịch web: dùng Roslyn trong VS Build Tools (csc của .NET Framework chỉ C# 5). Code nhúng trong `.aspx` là C# 5 nên mọi logic để ở code-behind. Thêm file .cs mới phải thêm vào `admin-web/myfschoolse1932web.csproj`.
- Công cụ trình duyệt: ảnh chụp chậm nửa giây sau mỗi thao tác (chụp lại sau khi chờ); chạm vào Flutter web theo toạ độ; app Flutter web phải gọi API qua CORS (đã cho phép `localhost:8090` trong `AllowedOrigins`).
- Git Bash: heredoc dài với dấu nháy hay lỗi; dùng công cụ Write/Edit. Cảnh báo "LF will be replaced by CRLF" là bình thường.
- `setState(() => _future = ...)` trả Future gây lỗi: luôn viết thân hàm dạng khối.
- Flutter hiển thị điểm bằng `toStringAsFixed(1)` nên 8.85 hiện là 8.8.
- Số trong PowerShell `Invoke-RestMethod` trả mảng có thể trông như 1 phần tử: dùng `ConvertFrom-Json` từ `Invoke-WebRequest` để đếm.

## Git
Nhánh `main`, remote `origin`. Lịch sử đợt này: backend API -> app 12 màn + design system -> admin-web -> mobile API C# -> chuyển app sang C# -> memory. Chủ dự án thường yêu cầu "commit push main"; hỏi nếu chưa rõ. Thông điệp commit kiểu `feat(app): ...`, kết thúc bằng dòng `Co-Authored-By: Claude ... <noreply@anthropic.com>`.
