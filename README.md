# MyFSchool

Flutter app + web service C# (`admin-web`) + SQL Server.

```
app Flutter -> web service C# (admin-web, /api/m, JWT bearer) -> SQL Server
```

Các trang Web Forms của portal dùng chung các service với web service này. Backend duy nhất là C#. Thư mục `backend/` (Node) chỉ là công cụ: `npm run db:init` tạo bảng + dữ liệu mẫu, `npm test` chạy 68 test hợp đồng vào `/api/m` của C#.

## Demo (khuyên dùng)

Nhấp đúp `demo.bat`: bật SQL Server + database, hỏi có đưa dữ liệu mẫu về ban đầu không, build và chạy web C# (`http://localhost:8088`), chạy app Flutter bản release ở cửa sổ riêng (`http://localhost:8090`) rồi mở cả hai trên trình duyệt. `demo.bat -Reset` / `demo.bat -NoReset` bỏ qua câu hỏi. Tắt: `demo-stop.bat`.

Ngoài 6 tài khoản gốc, `demo.bat` nạp thêm `backend/sql/demo-extra.sql` (một lần): 3 lớp 10A1/10A2/11A1 với 34 học sinh, 6 giáo viên (vd. GV `0902000001`), 31 phụ huynh (vd. PH có hai con `0904000001`), thời khóa biểu 10A2 và 11A1, điểm HK1, 18 đơn, thành viên CLB. Mật khẩu vẫn là `123456`. `demo.bat -BaseOnly` để chỉ dùng dữ liệu gốc.

## Chạy nhanh

Nhấp đúp `start.bat` (hoặc chạy nó trong terminal ở thư mục này). Script làm tất cả:

1. Kiểm tra Node (chỉ làm công cụ DB) và SQL Server, tự bật dịch vụ SQL Server nếu đang tắt (Windows sẽ hỏi quyền Admin một lần).
2. Tạo `backend/.env` với mật khẩu và JWT secret ngẫu nhiên nếu chưa có.
3. Tạo database `FSchoolDB` và tài khoản kết nối nếu chưa có.
4. Cài thư viện, tạo bảng, nạp tài khoản mẫu.
5. Bật portal C# ở `http://localhost:8088` (chạy nền, `admin-web\tools\run.ps1`; dừng bằng `admin-web\tools\stop.ps1`), chờ `/api/m/health` trả lời, rồi chạy app Flutter trên Chrome.

Chạy lại bao nhiêu lần cũng được. Chỉ cần dựng database và portal, không mở app: `powershell -ExecutionPolicy Bypass -File scripts\setup-backend.ps1`, rồi `powershell -ExecutionPolicy Bypass -File admin-web\tools\run.ps1`.

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
cd backend && npm test      # 68 test hợp đồng JSON vào /api/m của C# (portal phải đang chạy)
flutter analyze && flutter test
```

Công cụ database và bộ test hợp đồng: xem `backend/README.md`.
