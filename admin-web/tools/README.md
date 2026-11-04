# tools - build, chạy, kiểm thử (không cần IIS / Visual Studio)

Chạy từ thư mục web (hoặc bất kỳ đâu) bằng `powershell -ExecutionPolicy Bypass -File tools\<script>.ps1`.

| Script | Việc làm |
|---|---|
| `gen-connection.ps1` | Sinh `connections.config` từ `..\backend\.env` (thư mục gốc repo) (tham số `-EnvFile` nếu .env ở chỗ khác) |
| `build.ps1` | Biên dịch mọi `.cs` -> `bin\MyfschoolWeb.dll` (Roslyn csc của VS Build Tools) và `bin\MyfschoolHost.exe`; in lỗi gọn, exit 1 nếu lỗi |
| `run.ps1 [-Port 8088] [-NoBuild]` | Dừng bản cũ, (gen config nếu thiếu), build, chạy nền http://localhost:8088, đợi đến khi trả lời, ghi `tools\site.pid` (log: `tools\site.log`) |
| `stop.ps1` | Dừng site |
| `smoke.ps1` | Test HTTP: Login.aspx, logo, đăng nhập sai/PH/manager/GV, từng trang, chuyển hướng khi chưa đăng nhập |
| `MyfschoolHost.cs` | Self-host kiểu Cassini (HttpListener + ApplicationHost) phục vụ .aspx, Global.asax, /api, file tĩnh |

Ghi chú
- Request đầu tiên chậm (vài chục giây) vì ASP.NET biên dịch các trang `.aspx`.
- Sau khi sửa `.cs` phải chạy lại `run.ps1` (build + restart). Sửa `.aspx` thì chỉ cần F5.
- Chỉ truy cập qua `http://localhost:8088` (không phải 127.0.0.1).
- Cần SQL Server chạy (`Start-Service MSSQLSERVER`, cần quyền admin).
