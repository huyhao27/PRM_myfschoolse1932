# MyFSchool - Web quản lý (Trường THPT FPT Hà Nội)

Cổng web dành cho **Quản lý (Manager)** và **Giáo viên (GV)**: ASP.NET Web Forms + Web API 2 (.NET Framework 4.8),
dùng chung cơ sở dữ liệu **SQL Server `FSchoolDB`** với ứng dụng Flutter và Node API trong thư mục gốc của repo (thư mục cha của `admin-web`).
(Không còn dùng MongoDB; các DLL và vài class Mongo cũ còn lại chỉ để các trang chưa chuyển đổi vẫn biên dịch được.)

## Tài khoản
Mật khẩu demo của mọi tài khoản: `123456`. Đăng nhập bằng **số điện thoại** (hoặc email).

| Vai trò | Email | Số điện thoại | Quyền trên web |
|---|---|---|---|
| Manager | manager@fschool.vn | 0901000002 | Xem tất cả |
| GV | gv@fschool.vn | 0901000001 | Chỉ các lớp mình dạy (theo bảng Schedule) |
| GV | gv2@fschool.vn | 0901000005 | Chỉ các lớp mình dạy |

Tài khoản PH (phụ huynh) và HS (học sinh) bị từ chối vào portal.

## Chạy nhanh
1. Bảo đảm dịch vụ SQL Server (`MSSQLSERVER`) đang chạy và DB `FSchoolDB` đã khởi tạo (xem `backend\README.md` ở thư mục gốc repo).
2. Chạy `run_webapp.bat` (hoặc `powershell -ExecutionPolicy Bypass -File tools\run.ps1`) -> http://localhost:8088/Login.aspx
3. Dừng: `powershell -ExecutionPolicy Bypass -File tools\stop.ps1`

Máy không cần IIS/IIS Express: `tools\` có sẵn bộ self-host nhỏ. Chi tiết ở `tools\README.md`.

## Kết nối cơ sở dữ liệu
`Web.config` trỏ `<connectionStrings configSource="connections.config">`. File `connections.config` (chứa mật khẩu, **không commit**)
được sinh bởi `tools\gen-connection.ps1` từ `backend\.env` ở thư mục gốc repo; mẫu ở `connections.config.example`.
Truy cập dữ liệu qua `DataAccess\SqlDb.cs` (ADO.NET, chỉ dùng tham số).

## Cấu trúc
- `DataAccess\SqlDb.cs` - helper SQL Server; `MongoDbContext.cs` - cũ, sẽ bỏ.
- `Models\UserModel.cs`, `Services\StudentService.cs` - người dùng, đăng nhập (bcrypt), phân quyền lớp.
- Trang: Login, Default (dashboard), ListStudent, ListGrade, AddGrade, EditGrade, ViewGrade, ListSchedule, ImportData.
- `Content\fpt-logo.svg` - logo FPT Education (nguồn Wikimedia Commons).
- `tools\` - build / run / stop / smoke / gen-connection.

Lưu ý: code inline trong `.aspx` được biên dịch bằng compiler C# 5 của .NET Framework, hãy viết logic trong code-behind (`.cs`, C# mới nhất).
