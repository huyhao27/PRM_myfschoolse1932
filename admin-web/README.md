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

## Web service cho ứng dụng di động (`/api/m`)
Từ nay cổng web này là **backend duy nhất** của app Flutter: app -> JSON web service C# (`/api/m/*`) <-> SQL Server. Hợp đồng (endpoint, JSON, mã lỗi, thông báo tiếng Anh) giống hệt Node API trong `backend\`; app chỉ cần đổi base URL thành `http://<host>:8088` và prefix `/api/m`. Các API `/api/grades|students|schedules|import` của portal giữ nguyên.

Endpoint: `GET health`, `POST login`, `POST reset-password`, `GET me`, `GET children`, `GET schedule`, `GET schedule/{id}`, `GET grades`, `GET grades/{subject}`, `GET|POST requests`, `GET requests/{id}`, `POST requests/{id}/decision`, `GET clubs`, `GET clubs/{id}`, `POST clubs/{id}/join` (tất cả dưới `/api/m/`). Import lịch/học sinh/điểm vẫn chỉ làm trên web.

- **Mã**: `Controllers\Api\Mobile\` (controller, `MobileEdge` = CORS + header), `Services\MobileService.cs` (SQL + luật truy cập, cổng từ `backend\dao` và `controllers`), `MobileJwt.cs`, `MobileRateLimiter.cs`.
- **Token**: JWT HS256 chuẩn (`sub`, `role`, `iat`, `exp` = +1 giờ) tự cài bằng `HMACSHA256`, so sánh chữ ký hằng thời gian, chỉ nhận `alg=HS256`, token hết hạn -> `Token expired`, sai/giả -> `Invalid token`. Vai trò dùng để phân quyền luôn đọc lại từ DB mỗi request. Token không có `exp` bị từ chối.
- **Secret**: khóa ký là `JWT_SECRET` của `backend\.env`, nằm trong `secrets.config` (git-ignored, `<appSettings file="secrets.config">`), do `tools\gen-connection.ps1` sinh (mẫu: `secrets.config.example`). Nhờ đó token Node và C# dùng lẫn nhau. Không in/commit secret.
- **Đăng nhập app**: cả 4 vai trò (PH, HS, GV, Manager) bằng số điện thoại hoặc email; `Login.aspx` của portal vẫn chỉ cho Manager/GV. API không bao giờ trả `passwordHash`.
- **Stateless**: `/api/m` tắt session (`SessionStateBehavior.Disabled`), không có cookie.
- **CORS**: danh sách cho phép trong appSettings `AllowedOrigins` (mặc định `http://localhost:8090,http://localhost:8091,http://localhost:5555`); preflight `OPTIONS` cho phép `Authorization`, `Content-Type`; không bao giờ trả `*`. App Android/iOS native không gửi `Origin` nên không cần CORS. Mọi phản hồi có `X-Content-Type-Options: nosniff` và `Cache-Control: no-store`.
- **Chống lạm dụng** (bộ nhớ trong tiến trình, mất khi khởi động lại): đăng nhập sai 5 lần liên tiếp theo cặp *định danh + IP* trong 15 phút -> `429 {"message":"Too many attempts. Try again later."}` kèm `Retry-After` (đăng nhập đúng xóa bộ đếm; khi đang bị khóa, mật khẩu đúng cũng bị chặn đến hết cửa sổ); `reset-password` tối đa 5 lần/15 phút/cặp. Tùy chỉnh bằng appSettings `MobileRateLimitMax`, `MobileRateLimitWindowSeconds`. IP lấy từ socket (không tin `X-Forwarded-For`; nếu đặt sau reverse proxy phải cấu hình lại). Giới hạn đầu vào như Node: identifier <= 150, mật khẩu đăng nhập <= 256, `newPassword` 6..72, body <= 100 KB (413).
- **Lưu ý triển khai thật**: (1) **bắt buộc HTTPS** - host dev chỉ phục vụ `http://`, token và mật khẩu sẽ đi dạng rõ nếu không có TLS (đặt sau IIS/reverse proxy có chứng chỉ); (2) `reset-password` chỉ ở mức **demo**: không chứng minh quyền sở hữu tài khoản (không OTP/email), chỉ bị giới hạn tần suất - ai biết số điện thoại/email đều đổi được mật khẩu; chưa làm OTP/email; (3) bộ giới hạn tần suất theo định danh+IP chưa chặn kẻ tấn công xoay vòng nhiều định danh.
- **Kiểm thử**: bộ test Node dùng lại được cho C#: chạy site (`tools\locked.ps1 -KeepRunning`), rồi `cd backend` và `set API_BASE=http://localhost:8088`, `set API_PREFIX=/api/m`, `npm test`. Phần C# không có trong bộ Node (rate limit, token giả/hết hạn, CORS, không cookie) nằm ở `tools\smoke-mobile.ps1`.
