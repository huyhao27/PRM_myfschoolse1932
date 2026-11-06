# 01. Logic và kiến trúc MyFSchool

## Sản phẩm
Hệ thống quản lý trường THPT FPT: **app Flutter** (phụ huynh PH, học sinh HS, giáo viên GV, quản lý Manager) và **web quản trị** (chỉ Manager và GV). Tiếng Việt, màu cam FPT `#F37021`. Đồ án PRM392.

## Cấu trúc repo
```
lib/, test/        App Flutter (Dart). 12 màn theo design/figma/*.svg
admin-web/         Web quản trị ASP.NET Web Forms (.NET Framework 4.8) + Web API 2  => BACKEND DUY NHẤT của app
backend/           Node, chỉ là công cụ (API Express đã xoá 06/11/2026): (1) `npm run db:init` tạo bảng + dữ liệu mẫu (sql/), (2) 68 test hợp đồng, mặc định bắn vào C# http://localhost:8088/api/m.
scripts/, start.bat   Dựng SQL Server/DB và khởi động
design-system/myfschool/MASTER.md   Token màu, chữ, thành phần, trợ năng (rút ra từ skill ui-ux-pro-max)
design/            Mockup Figma/SVG, trang code-explained.html
assets/images/fpt_education_logo.svg   Logo chính thức (không vẽ lại, không đổi màu)
.claude/memory/    Thư mục này
```
Web gốc (nguồn nhận về, ngoài repo): `D:\Ki8\PRM\Project\myfschoolse1932web\myfschoolse1932web` (bản MongoDB của bên khác). Bản dùng thật là `admin-web/` trong repo. Các artifact giải thích (claude.ai, riêng tư): hướng dẫn demo, flow test thủ công, app Flutter, web quản trị.

## Kiến trúc (đã chốt)
```
Flutter app ──JSON + JWT Bearer──► Web service C# (admin-web, /api/m, cổng 8088) ──► SQL Server FSchoolDB (1433)
Trình duyệt quản lý/GV ──Web Forms + cookie session──► cùng server C# ───────────────┘
```
- App **không** gọi web quản trị trực tiếp; cùng một backend C# và cùng database. App chủ yếu xem; nhập lịch học, danh sách học sinh, điểm chỉ làm trên web (Import CSV, chỉ Manager).
- Quyết định của chủ dự án: C# là backend duy nhất (kiểu "app gọi web service như Firebase"). Node chỉ còn là công cụ DB và bộ test hợp đồng (không còn server Express).
- Ghi từ app (chủ dự án chọn giữ cả bốn): PH/HS tạo đơn, GV/Manager duyệt đơn, HS xin vào CLB, đặt lại mật khẩu.
- Đăng nhập app **chỉ bằng số điện thoại** (backend vẫn nhận email). Web cũng nhận SĐT (hoặc email), chỉ cho Manager/GV.

## Dữ liệu (SQL Server FSchoolDB, schema ở backend/sql/schema.sql, seed ở seed.sql)
Users(id,name,email,phone,passwordHash bcrypt,role GV|Manager|PH|HS,className), ParentStudent(parentId,studentId), Schedule(teacherId,className,subject,dayOfWeek 1-7,period,startTime,endTime,room,mode,content,prep,note), Grade(studentId,subject,score,term,type,weight,gradeDate), GradeRemark(studentId,subject,term,teacherId,comment), TermSummary(studentId,term,conduct), Requests(studentId,createdBy,type,fromDate,toDate,reason,status pending|approved|rejected,teacherComment,handledBy,handledAt,createdAt UTC), Clubs(name,icon,description,meeting,location,advisor,president,baseMembers), ClubMembers(clubId,userId,status pending|approved).
Dữ liệu mẫu (mật khẩu `123456`): gv 0901000001, manager 0901000002, ph 0901234567 (2 con), hs 0901000003 "Hoc sinh Demo", hs2 0901000004 "Hoc sinh Mai", gv2 0901000005 (email `gv@/manager@/ph@/hs@/hs2@/gv2@fschool.vn`). Seed: 6 user, 29 tiết lớp 10A1, 96 điểm, 4 đơn (2 chờ), 5 CLB, 2 thành viên CLB (hs: Bóng đá approved, Âm nhạc pending).

## Quy tắc nghiệp vụ (phải giữ giống nhau ở C# và test Node)
- **Ai thấy học sinh nào** (MỘT chỗ: `Roles.StudentScope` trong `admin-web/Models/UserModel.cs`, MobileService và RequestService cùng gọi): HS chỉ mình; PH các con trong ParentStudent; GV học sinh các lớp có trong Schedule của mình; Manager mọi HS.
- **Điểm trung bình** = trung bình có hệ số, làm tròn 2 chữ số (AwayFromZero). Hệ số: Miệng 1, 15 phút 1, 1 tiết 2, Giữa kỳ 2, Cuối kỳ 3. Xếp loại: >=8 Giỏi (web: Tốt), >=6.5 Khá, >=5 Trung bình (web: Đạt), còn lại Yếu (Chưa đạt). Toán của hs = 8.85 (app hiển thị 8.8 vì `toStringAsFixed(1)`). Tổng kỳ HK1 của hs ≈ 8.43.
- **Đơn từ**: tạo bởi HS (cho mình) hoặc PH (cho con); loại: Xin nghỉ học | Xin phép đi trễ | Xin đổi chỗ ngồi; lý do bắt buộc <=500 ký tự; ngày yyyy-MM-dd, toDate>=fromDate. Duyệt chỉ GV/Manager, chỉ đơn trong phạm vi nhìn thấy, bằng một câu `UPDATE ... WHERE status='pending'` (đã xử lý rồi thì 409). Đơn ngoài phạm vi = "không tìm thấy".
- **CLB**: HS xin vào => `pending`; duyệt/từ chối trên web (Manager và GV, GV không bị giới hạn theo lớp); từ chối xoá dòng pending. memberCount = baseMembers + số approved. Sửa/tạo CLB chỉ Manager.
- **GV sửa điểm**: chỉ môn mình dạy ở lớp đó (suy từ Schedule, `CanonSubject` đổi Lý->Vật lý, Hóa->Hóa học, Tin->Tin học, Văn->Ngữ văn, Anh->Tiếng Anh, Sinh->Sinh học, Sử->Lịch sử, Địa->Địa lý). Manager sửa tất cả.
- **Tài khoản (web)**: chỉ Manager tạo/sửa/đặt lại mật khẩu/xoá/liên kết PH. Xoá bị từ chối nếu còn điểm, đơn, CLB, tiết hoặc là chính mình. Mật khẩu mặc định tài khoản mới và import: `123456`.
- **Thời khóa biểu (web)**: giờ cố định theo tiết (07:30-08:15, 08:25-09:10, 09:20-10:05, 10:15-11:00, 11:10-11:55...), không trùng lớp-thứ-tiết, giáo viên không dạy hai lớp cùng lúc.
- **Import CSV (Manager)**: tài khoản, thời khóa biểu, điểm; một giao dịch, dòng lỗi bỏ qua và liệt kê, upsert nên import lại không trùng.

## Xác thực và bảo mật
- Mật khẩu bcrypt cost 10 (bcryptjs bên Node, BCrypt.Net-Next bên C#, đọc được hash của nhau).
- Mobile: JWT HS256 viết tay (`admin-web/Services/MobileJwt.cs`), claim sub/role/iat/exp (1 giờ), khoá = JWT_SECRET trong `backend/.env`, ghi vào `admin-web/secrets.config` (git bỏ qua) bởi `tools/gen-connection.ps1`. Vai trò được đọc lại từ DB mỗi yêu cầu. Chỉ chấp nhận alg HS256, thiếu exp bị từ chối.
- Chống tấn công mobile: giới hạn 5 lần đăng nhập sai / 5 lần reset mỗi định danh+IP mỗi 15 phút (429, trong bộ nhớ), CORS theo danh sách `AllowedOrigins` (mặc định `http://localhost:*,http://127.0.0.1:*`: mọi cổng localhost, vì Android Studio `flutter run -d chrome` dùng cổng ngẫu nhiên; tên miền khác bị chặn), không cookie session cho `/api/m`, header nosniff + no-store, truy vấn tham số hoá, giới hạn body 100 KB, không lộ passwordHash.
- Web: session ASP.NET InProc 120 phút, mọi trang chốt quyền (Site.Master + từng trang), `ApiSessionModule` bật session cho `/api/*` trừ `/api/m`.
- Đặt lại mật khẩu: mức demo (không xác minh chủ tài khoản). Cần OTP nếu đưa thật. Dev chạy http; triển khai cần HTTPS.

## API mobile `/api/m` (hợp đồng = Node API cũ, cùng JSON)
health, login (POST, mọi vai trò), reset-password (POST), me, children, schedule, schedule/{id}, grades?studentId&term, grades/{subject}, requests (GET, POST), requests/{id}, requests/{id}/decision (POST {decision:'approved'|'rejected', comment}), clubs, clubs/{id}, clubs/{id}/join (POST). Lỗi: JSON `{message}` tiếng Anh; 400/401/403/404/409/413/429/500. App Flutter đặt tiền tố ở **một chỗ**: `lib/services/api_config.dart` (`ApiConfig.prefix`, mặc định `/api/m`; base URL mặc định `http://localhost:8088`, Android emulator `http://10.0.2.2:8088`; đổi bằng `--dart-define=API_BASE_URL=... API_PREFIX=...`).
Web còn API riêng `/api/students|grades|schedules|import` (session hoặc Basic), app không dùng.

## App Flutter (lib/)
Không dùng gói quản lý trạng thái: StatefulWidget + setState + FutureBuilder. Tầng: screen -> services (`SchoolService`, `AuthService`) -> `ApiClient` (ánh xạ mọi lỗi thành `AuthException`, timeout 10 giây, gắn Bearer từ `Session`) -> models. Tiêm service qua tham số tùy chọn của từng màn (để test bằng MockClient). Theme và token: `lib/theme/`. Widget dùng chung: `lib/screen/widgets.dart` (FutureView, SkeletonList, EmptyState, ErrorState, StatusBadge, ...). Home hiện ô theo vai trò (`tilesForRole`): Bảng điểm chỉ PH, HS.
Phụ thuộc: http, flutter_svg (logo). 76 test (MockClient, không cần server).

## Web quản trị (admin-web/)
Trang: Login, Default (bảng điều khiển), ListStudent, ListSchedule, ListGrade/AddGrade/EditGrade/ViewGrade, ListRequest/ViewRequest, ListClub/ViewClub, ImportData. `Services/` giữ nghiệp vụ + SQL qua `DataAccess/SqlDb.cs` (Query/Scalar/Execute/Transaction, luôn tham số hoá). Mobile: `Controllers/Api/Mobile/*` (MobileApiController, MobileEdge, MobileEndpoints) + `Services/MobileService.cs`, `MobileJwt.cs`, `MobileRateLimiter.cs`. Giao diện mới (thanh bên + `Content/site.css`) mới áp cho Login và Default; 10 trang còn lại dùng lớp cũ (`btn-fpt`, `card-custom`, `table-custom`) qua bí danh trong CSS.

## Những thứ còn thiếu / hạn chế đã biết
Chưa có OTP; không thông báo đẩy; phiên app không lưu (mất khi tắt); Bảng điều khiển tính trung bình thường chứ không có hệ số; GV duyệt CLB không giới hạn theo lớp; tài liệu/ảnh chụp giao diện thật chưa xem đủ mọi màn trên trình duyệt thật.
