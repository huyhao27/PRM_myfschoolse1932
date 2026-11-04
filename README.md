# MyFSchool

Flutter app + Node/Express API + SQL Server (phương án 3: app gọi Web API, API gọi database).

## Chạy nhanh

Nhấp đúp `start.bat` (hoặc chạy nó trong terminal ở thư mục này). Script làm tất cả:

1. Kiểm tra Node và SQL Server, tự bật dịch vụ SQL Server nếu đang tắt (Windows sẽ hỏi quyền Admin một lần).
2. Tạo `backend/.env` với mật khẩu và JWT secret ngẫu nhiên nếu chưa có.
3. Tạo database `FSchoolDB` và tài khoản kết nối nếu chưa có.
4. Cài thư viện, tạo bảng, nạp tài khoản mẫu.
5. Bật backend ở cổng 3000 (cửa sổ riêng), rồi chạy app Flutter trên Chrome.

Chạy lại bao nhiêu lần cũng được. Chỉ cần dựng database và backend, không mở app: `powershell -ExecutionPolicy Bypass -File scripts\setup-backend.ps1`, rồi `cd backend` và `npm start`.

Tài khoản mẫu (mật khẩu `123456`). App đăng nhập bằng **số điện thoại** (API vẫn nhận cả email):

| Vai trò | Email | SĐT |
|---|---|---|
| GV | gv@fschool.vn | 0901000001 |
| Manager | manager@fschool.vn | 0901000002 |
| PH | ph@fschool.vn | 0901234567 |
| HS | hs@fschool.vn | 0901000003 |
| HS | hs2@fschool.vn | 0901000004 |
| GV | gv2@fschool.vn | 0901000005 |

## Chạy trên thiết bị khác

- Máy ảo Android: app tự dùng `http://10.0.2.2:3000`.
- Điện thoại thật: `flutter run --dart-define=API_BASE_URL=http://<IP máy chạy backend>:3000`, và cho phép cổng 3000 qua tường lửa.

## Kiểm tra

```
cd backend && npm test      # 62 test API trên database thật
flutter analyze && flutter test
```

Chi tiết API, lỗi thường gặp và cách đổi database: xem `backend/README.md`.
