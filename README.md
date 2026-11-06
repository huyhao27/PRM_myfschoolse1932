# MyFSchool

Flutter app + web service C# (`admin-web`) + SQL Server.

```
app Flutter -> web service C# (admin-web, /api/m, JWT bearer) -> SQL Server
```

Các trang Web Forms của portal dùng chung các service với web service này. API Node (`backend/`) là bản cũ: giữ lại để chạy `npm run db:init` (tạo bảng + dữ liệu mẫu) và làm chuẩn đối chiếu hợp đồng JSON, app không còn gọi nó.

## Chạy nhanh

Nhấp đúp `start.bat` (hoặc chạy nó trong terminal ở thư mục này). Script làm tất cả:

1. Kiểm tra Node (chỉ làm công cụ DB) và SQL Server, tự bật dịch vụ SQL Server nếu đang tắt (Windows sẽ hỏi quyền Admin một lần).
2. Tạo `backend/.env` với mật khẩu và JWT secret ngẫu nhiên nếu chưa có.
3. Tạo database `FSchoolDB` và tài khoản kết nối nếu chưa có.
4. Cài thư viện, tạo bảng, nạp tài khoản mẫu.
5. Bật portal C# ở `http://localhost:8088` (chạy nền, `admin-web	oolsun.ps1`; dừng bằng `admin-web	ools\stop.ps1`), chờ `/api/m/health` trả lời, rồi chạy app Flutter trên Chrome.

Chạy lại bao nhiêu lần cũng được. Chỉ cần dựng database và portal, không mở app: `powershell -ExecutionPolicy Bypass -File scripts\setup-backend.ps1`, rồi `powershell -ExecutionPolicy Bypass -File admin-web	oolsun.ps1`.

Tài khoản mẫu (mật khẩu `123456`). App chỉ nhận **số điện thoại** để đăng nhập (API vẫn nhận cả email):

| Vai trò | Email | SĐT |
|---|---|---|
| GV | gv@fschool.vn | 0901000001 |
| Manager | manager@fschool.vn | 0901000002 |
| PH | ph@fschool.vn | 0901234567 |
| HS | hs@fschool.vn | 0901000003 |
| HS | hs2@fschool.vn | 0901000004 |
| GV | gv2@fschool.vn | 0901000005 |

## Chạy trên thiết bị khác

- Máy ảo Android: app tự dùng `http://10.0.2.2:8088`; web/desktop dùng `http://localhost:8088`.
- Điện thoại thật: `flutter run --dart-define=API_BASE_URL=http://<IP máy chạy portal>:8088`, và cho phép cổng 8088 qua tường lửa.
- Tiền tố API mặc định `/api/m` (đổi bằng `--dart-define=API_PREFIX=...`), định nghĩa một chỗ ở `lib/services/api_config.dart`.

## Kiểm tra

```
cd backend && npm test      # 62 test hợp đồng JSON của API Node (chuẩn đối chiếu)
flutter analyze && flutter test
```

Chi tiết hợp đồng API (bản Node), lỗi thường gặp và cách đổi database: xem `backend/README.md`.
