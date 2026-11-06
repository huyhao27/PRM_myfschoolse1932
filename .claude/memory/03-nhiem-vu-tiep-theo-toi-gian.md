# 03. Nhiệm vụ tiếp theo: tối giản code, mềm và dễ hiểu hơn, giữ đủ luồng

## Yêu cầu của chủ dự án (nguyên ý)
"Tối giản logic, làm mềm code hơn, đơn giản hơn, dễ hiểu hơn, lược bớt, nhưng vẫn đủ luồng."
Hiểu là: bớt mã, bớt trừu tượng thừa, bớt lặp, đặt tên và cấu trúc dễ đọc, nhưng **không mất chức năng nào** của các luồng hiện có (xem `01-logic-va-kien-truc.md`). Đây là dự án học tập: ưu tiên dễ giải thích với giảng viên hơn là "đủ tính năng cho môi trường thật".

## Quy tắc khi làm
1. **Giữ nguyên hành vi nhìn thấy được**: hợp đồng JSON của `/api/m`, schema và dữ liệu mẫu, văn bản tiếng Việt trên giao diện, các luồng ở phần dưới. Nếu muốn bỏ một tính năng, hỏi chủ dự án trước.
2. **Làm từng khu vực một**, đo số dòng trước và sau, commit riêng cho mỗi khu vực (`refactor(app): ...`), chạy bộ test sau mỗi khu vực. Không gộp refactor với đổi tính năng.
3. Test là lưới an toàn: chỉ sửa test khi hành vi **cố ý** đổi; không nới lỏng assert để cho qua. Khi xoá mã thì xoá luôn test của mã đó.
4. Có thể chạy song song bằng subagent nhưng mỗi agent sở hữu tập file riêng; web phải build/chạy qua `admin-web\tools\locked.ps1`.
5. Giữ nguyên các cơ chế an toàn đã có (truy vấn tham số hoá, bcrypt, kiểm quyền ở máy chủ, giới hạn tần suất). Đơn giản hoá không có nghĩa là bỏ kiểm tra quyền.

## Đo hiện trạng (để so sánh)
| Khu vực | Số dòng (đo lúc chốt) |
|---|---|
| `lib/` (Dart) | ≈ 4140 (lớn nhất: widgets.dart 605, schedule_screen 318, signup_screen 287 (mã chết), login_screen 280, models/school.dart 259, app_theme 240) |
| `test/` (Dart) | ≈ 1390 |
| `backend/` (JS, không tính lockfile) | ≈ 1444 |
| `admin-web` C# + aspx (không tính designer, tools) | ≈ 7380 (MobileService 508, ImportService 451, StudentService 421, GradeService 326, MobileEndpoints 283, ListStudent.aspx.cs 271, ListSchedule.aspx.cs 205, ScheduleService 203) |
| `admin-web` CSS+JS | ≈ 630 |
| `admin-web/tools` (ps1 + host) | ≈ 1650 |

## Ứng viên rút gọn (gợi ý, kiểm chứng trước khi xoá)
**Chắc chắn là mã chết hoặc thừa**
- `lib/screen/signup_screen.dart` (không màn nào mở), `lib/main-init.txt`, `lib/screen/app_colors.dart` (chỉ còn là bí danh), `validateEmailOrPhone` nếu chỉ signup dùng.
- Web: `DataAccess/MongoDbContext.cs`, các DLL MongoDB/DnsClient/SharpCompress/Snappier/ZstdSharp/mongocrypt trong `bin/` và khoá cấu hình cũ, các thành viên `[Obsolete]` trên `UserModel`, khối "legacy alias" trong `Content/site.css` (sau khi các trang chuyển sang lớp mới).
- `backend/`: toàn bộ API Express (controllers, dao, middleware, server.js) chỉ còn làm "chuẩn đối chiếu". Quyết định cần chủ dự án: (a) giữ làm test hợp đồng, hoặc (b) thay bằng test trực tiếp vào C# và chỉ giữ `sql/` + `init.js` (hoặc viết lại `db:init` bằng PowerShell/SQL để bỏ hẳn Node).

**Lặp và có thể gộp**
- Quy tắc "ai thấy học sinh nào", công thức điểm và duyệt đơn đang có **hai bản** (Node, C#) và trong C# còn hai chỗ: dịch vụ cổng web (`StudentService/GradeService/RequestService/ClubService`) và `MobileService`. Cho `MobileService` gọi lại các dịch vụ cổng web (mở rộng chúng cho PH/HS) để chỉ còn một nơi chứa quy tắc.
- Web: hàm hiển thị thông báo `ShowError/ShowAlert/ShowOk/ShowMsg` lặp ở từng trang, chốt quyền lặp ở từng trang (đã có ở Site.Master); `Default.aspx.cs` tính điểm khác `GradeService`. Có thể dùng một lớp `PageBase` cho cả hai.
- Web giao diện: 10 trang còn dùng lớp cũ; hoàn tất chuyển sang bộ lớp trong `Content/site.css`/`README-ui.md` rồi xoá bí danh.
- Flutter: `widgets.dart` (605 dòng) gom nhiều widget; tách hoặc bớt (ScoreLegend/ScoreBadge, SkeletonList...) nếu chỉ dùng một chỗ; `school.dart` có nhiều lớp mô hình lặp mẫu `fromJson`; `request_add_screen`, `club_*` có thể ngắn hơn. Có thể giảm số màn dùng cùng mẫu "chọn học sinh cho PH".
- `ImportService` (451 dòng) và `ListStudent.aspx.cs` (271) là hai khối lớn nhất của web: xem có thể bỏ loại import ít dùng (điểm) hoặc rút phần kiểm tra lặp.
- `admin-web/tools`: nhiều script smoke lặp mẫu đăng nhập; có thể gom vào một module dùng chung.

**Không nên đụng nếu không có lý do**
Hợp đồng `/api/m`, schema SQL, chuỗi tiếng Việt trên UI, các cơ chế bảo mật ở phần 01.

## Luồng phải còn đủ sau khi rút gọn (checklist)
App: đăng nhập SĐT; Home theo vai trò; thời khóa biểu (tuần, chi tiết tiết); bảng điểm (tổng, chi tiết môn); đơn từ (danh sách, lọc, tạo, chi tiết, duyệt/từ chối bởi GV/Manager); CLB (danh sách, tìm, chi tiết, xin tham gia); đặt lại mật khẩu; đăng xuất; phụ huynh chọn con.
Web: đăng nhập Manager/GV, bảng điều khiển, tài khoản (tạo/sửa/đặt lại mật khẩu/liên kết PH/xoá an toàn), thời khóa biểu (thêm/sửa/xoá, xung đột), sổ điểm (xem/nhập/sửa/xoá, GV chỉ môn mình dạy), đơn từ (duyệt), CLB (duyệt thành viên, sửa CLB), import CSV.
Liên thông: đơn tạo ở app -> duyệt ở web -> app thấy kết quả; xin vào CLB ở app -> duyệt ở web; tài khoản tạo ở web đăng nhập được ở app; điểm sửa ở web hiện ở app.

## Tiêu chí xong (phải đạt tất cả)
`flutter analyze` sạch; `flutter test` xanh; `npm test` (nếu còn bộ Node) xanh cả hai chế độ; các `smoke-*.ps1` xanh; dữ liệu mẫu về nguyên trạng; số dòng giảm có số liệu (nêu bảng trước/sau); chạy thử thật app (cổng 8090) + web (cổng 8088) một vòng; báo cáo ngắn nêu đã bỏ gì, giữ gì.

## Gợi ý thứ tự
1. Xoá mã chết (an toàn, thấy ngay hiệu quả). 2. Thống nhất quy tắc C# về một nơi (MobileService dùng lại dịch vụ web). 3. Quyết định số phận `backend/` (hỏi chủ dự án). 4. Rút gọn Flutter (widgets, models, màn lặp). 5. Rút gọn web (PageBase, dọn trang, giao diện về một bộ lớp). 6. Cập nhật lại các tài liệu/artifact và `README.md`, `.claude/memory/`.
