-- Extra demo data (generated, deterministic): 6 teachers, 34 students in 10A1/10A2/11A1, their parents,
-- timetables of 10A2 and 11A1, HK1 grades + remarks + conduct, 18 requests, club memberships. Password 123456.
-- Runs once (skips when hs101@fschool.vn exists). Needs the base seed (npm run db:init) first.
-- Leaves untouched what the tests rely on: 10A1 timetable (29), the 6 base accounts and their data, 5 clubs, CLB Lập trình = 56.
SET QUOTED_IDENTIFIER ON;  -- the filtered unique indexes on Users need it
GO
SET NOCOUNT ON;
IF EXISTS (SELECT 1 FROM dbo.Users WHERE email = 'hs101@fschool.vn') BEGIN PRINT 'Demo extra data already present.'; RETURN; END
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE email = 'gv@fschool.vn') BEGIN PRINT 'Run npm run db:init first.'; RETURN; END
BEGIN TRAN;
DECLARE @h NVARCHAR(100) = N'$2b$10$d5FcD3iF4uY9wob2InVmHevAWsJb.NH7leCVOLNDT98eDYsuSvSky';
INSERT dbo.Users (name, email, phone, passwordHash, role, className)
SELECT v.name, v.email, v.phone, @h, v.role, v.className FROM (VALUES
  (N'Nguyễn Thị Hương', 'huong.nt@fschool.vn', '0902000001', 'GV', NULL),
  (N'Trần Quốc Bảo', 'bao.tq@fschool.vn', '0902000002', 'GV', NULL),
  (N'Lê Thu Trang', 'trang.lt@fschool.vn', '0902000003', 'GV', NULL),
  (N'Phạm Đức Anh', 'ducanh.p@fschool.vn', '0902000004', 'GV', NULL),
  (N'Hoàng Minh Châu', 'chau.hm@fschool.vn', '0902000005', 'GV', NULL),
  (N'Đỗ Văn Hùng', 'hung.dv@fschool.vn', '0902000006', 'GV', NULL),
  (N'Bùi Thành Khoa', 'hs101@fschool.vn', '0903000001', 'HS', N'10A1'),
  (N'Đặng Hoàng Vinh', 'hs102@fschool.vn', '0903000002', 'HS', N'10A1'),
  (N'Dương Anh Cường', 'hs103@fschool.vn', '0903000003', 'HS', N'10A1'),
  (N'Trần Hoàng Vinh', 'hs104@fschool.vn', '0903000004', 'HS', N'10A1'),
  (N'Bùi Khánh Chi', 'hs105@fschool.vn', '0903000005', 'HS', N'10A1'),
  (N'Dương Minh Hiếu', 'hs106@fschool.vn', '0903000006', 'HS', N'10A1'),
  (N'Trần Văn Tùng', 'hs107@fschool.vn', '0903000007', 'HS', N'10A1'),
  (N'Dương Thu Hà', 'hs108@fschool.vn', '0903000008', 'HS', N'10A1'),
  (N'Phạm Thị Hương', 'hs109@fschool.vn', '0903000009', 'HS', N'10A1'),
  (N'Huỳnh Thành Quân', 'hs110@fschool.vn', '0903000010', 'HS', N'10A1'),
  (N'Hoàng Thành Hiếu', 'hs111@fschool.vn', '0903000011', 'HS', N'10A2'),
  (N'Lý Đức Tùng', 'hs112@fschool.vn', '0903000012', 'HS', N'10A2'),
  (N'Bùi Ngọc Hương', 'hs113@fschool.vn', '0903000013', 'HS', N'10A2'),
  (N'Bùi Khánh Hương', 'hs114@fschool.vn', '0903000014', 'HS', N'10A2'),
  (N'Huỳnh Khánh Quỳnh', 'hs115@fschool.vn', '0903000015', 'HS', N'10A2'),
  (N'Bùi Thị Hân', 'hs116@fschool.vn', '0903000016', 'HS', N'10A2'),
  (N'Lý Minh Tùng', 'hs117@fschool.vn', '0903000017', 'HS', N'10A2'),
  (N'Võ Khánh Anh', 'hs118@fschool.vn', '0903000018', 'HS', N'10A2'),
  (N'Dương Quang Quân', 'hs119@fschool.vn', '0903000019', 'HS', N'10A2'),
  (N'Lê Thanh Mai', 'hs120@fschool.vn', '0903000020', 'HS', N'10A2'),
  (N'Bùi Bảo Trang', 'hs121@fschool.vn', '0903000021', 'HS', N'10A2'),
  (N'Phan Thị Lan', 'hs122@fschool.vn', '0903000022', 'HS', N'10A2'),
  (N'Nguyễn Thanh My', 'hs123@fschool.vn', '0903000023', 'HS', N'11A1'),
  (N'Ngô Quang Hiếu', 'hs124@fschool.vn', '0903000024', 'HS', N'11A1'),
  (N'Hồ Thanh My', 'hs125@fschool.vn', '0903000025', 'HS', N'11A1'),
  (N'Bùi Khánh Thảo', 'hs126@fschool.vn', '0903000026', 'HS', N'11A1'),
  (N'Ngô Thị Hà', 'hs127@fschool.vn', '0903000027', 'HS', N'11A1'),
  (N'Hoàng Khánh Hương', 'hs128@fschool.vn', '0903000028', 'HS', N'11A1'),
  (N'Đỗ Minh Vy', 'hs129@fschool.vn', '0903000029', 'HS', N'11A1'),
  (N'Ngô Thu Mai', 'hs130@fschool.vn', '0903000030', 'HS', N'11A1'),
  (N'Huỳnh Thị Trang', 'hs131@fschool.vn', '0903000031', 'HS', N'11A1'),
  (N'Dương Thu Anh', 'hs132@fschool.vn', '0903000032', 'HS', N'11A1'),
  (N'Lê Gia Tùng', 'hs133@fschool.vn', '0903000033', 'HS', N'11A1'),
  (N'Vũ Thanh Chi', 'hs134@fschool.vn', '0903000034', 'HS', N'11A1'),
  (N'Bùi Văn Mạnh', 'ph101@fschool.vn', '0904000001', 'PH', NULL),
  (N'Đặng Đức Đông', 'ph102@fschool.vn', '0904000002', 'PH', NULL),
  (N'Dương Văn Toàn', 'ph103@fschool.vn', '0904000003', 'PH', NULL),
  (N'Trần Quốc Toàn', 'ph104@fschool.vn', '0904000004', 'PH', NULL),
  (N'Bùi Thu Hạnh', 'ph105@fschool.vn', '0904000005', 'PH', NULL),
  (N'Dương Đức Mạnh', 'ph106@fschool.vn', '0904000006', 'PH', NULL),
  (N'Trần Ngọc Hạnh', 'ph107@fschool.vn', '0904000007', 'PH', NULL),
  (N'Dương Quốc Hùng', 'ph108@fschool.vn', '0904000008', 'PH', NULL),
  (N'Phạm Văn Lực', 'ph109@fschool.vn', '0904000009', 'PH', NULL),
  (N'Huỳnh Đức Đông', 'ph110@fschool.vn', '0904000010', 'PH', NULL),
  (N'Hoàng Thị Thủy', 'ph111@fschool.vn', '0904000011', 'PH', NULL),
  (N'Lý Thị Dung', 'ph112@fschool.vn', '0904000012', 'PH', NULL),
  (N'Bùi Quốc Hải', 'ph113@fschool.vn', '0904000013', 'PH', NULL),
  (N'Huỳnh Thị Thủy', 'ph114@fschool.vn', '0904000014', 'PH', NULL),
  (N'Bùi Văn Trung', 'ph115@fschool.vn', '0904000015', 'PH', NULL),
  (N'Lý Đức Hùng', 'ph116@fschool.vn', '0904000016', 'PH', NULL),
  (N'Võ Ngọc Hoa', 'ph117@fschool.vn', '0904000017', 'PH', NULL),
  (N'Dương Thu Nga', 'ph118@fschool.vn', '0904000018', 'PH', NULL),
  (N'Lê Quốc Mạnh', 'ph119@fschool.vn', '0904000019', 'PH', NULL),
  (N'Bùi Thị Hạnh', 'ph120@fschool.vn', '0904000020', 'PH', NULL),
  (N'Phan Ngọc Hạnh', 'ph121@fschool.vn', '0904000021', 'PH', NULL),
  (N'Nguyễn Thu Thủy', 'ph122@fschool.vn', '0904000022', 'PH', NULL),
  (N'Ngô Văn Lực', 'ph123@fschool.vn', '0904000023', 'PH', NULL),
  (N'Hồ Thị Nga', 'ph124@fschool.vn', '0904000024', 'PH', NULL),
  (N'Ngô Quốc Đông', 'ph125@fschool.vn', '0904000025', 'PH', NULL),
  (N'Hoàng Đức Trung', 'ph126@fschool.vn', '0904000026', 'PH', NULL),
  (N'Đỗ Quốc Mạnh', 'ph127@fschool.vn', '0904000027', 'PH', NULL),
  (N'Ngô Đức Hải', 'ph128@fschool.vn', '0904000028', 'PH', NULL),
  (N'Dương Ngọc Nga', 'ph129@fschool.vn', '0904000029', 'PH', NULL),
  (N'Lê Thị Thủy', 'ph130@fschool.vn', '0904000030', 'PH', NULL),
  (N'Vũ Thị Hoa', 'ph131@fschool.vn', '0904000031', 'PH', NULL)
) AS v(name, email, phone, role, className);

INSERT dbo.ParentStudent (parentId, studentId) SELECT p.id, s.id FROM (VALUES
  ('ph101@fschool.vn', 'hs101@fschool.vn'),
  ('ph102@fschool.vn', 'hs102@fschool.vn'),
  ('ph103@fschool.vn', 'hs103@fschool.vn'),
  ('ph104@fschool.vn', 'hs104@fschool.vn'),
  ('ph105@fschool.vn', 'hs105@fschool.vn'),
  ('ph106@fschool.vn', 'hs106@fschool.vn'),
  ('ph107@fschool.vn', 'hs107@fschool.vn'),
  ('ph108@fschool.vn', 'hs108@fschool.vn'),
  ('ph109@fschool.vn', 'hs109@fschool.vn'),
  ('ph110@fschool.vn', 'hs110@fschool.vn'),
  ('ph111@fschool.vn', 'hs111@fschool.vn'),
  ('ph112@fschool.vn', 'hs112@fschool.vn'),
  ('ph101@fschool.vn', 'hs113@fschool.vn'),
  ('ph113@fschool.vn', 'hs114@fschool.vn'),
  ('ph114@fschool.vn', 'hs115@fschool.vn'),
  ('ph115@fschool.vn', 'hs116@fschool.vn'),
  ('ph116@fschool.vn', 'hs117@fschool.vn'),
  ('ph117@fschool.vn', 'hs118@fschool.vn'),
  ('ph118@fschool.vn', 'hs119@fschool.vn'),
  ('ph119@fschool.vn', 'hs120@fschool.vn'),
  ('ph120@fschool.vn', 'hs121@fschool.vn'),
  ('ph121@fschool.vn', 'hs122@fschool.vn'),
  ('ph122@fschool.vn', 'hs123@fschool.vn'),
  ('ph123@fschool.vn', 'hs124@fschool.vn'),
  ('ph124@fschool.vn', 'hs125@fschool.vn'),
  ('ph105@fschool.vn', 'hs126@fschool.vn'),
  ('ph125@fschool.vn', 'hs127@fschool.vn'),
  ('ph126@fschool.vn', 'hs128@fschool.vn'),
  ('ph127@fschool.vn', 'hs129@fschool.vn'),
  ('ph128@fschool.vn', 'hs130@fschool.vn'),
  ('ph114@fschool.vn', 'hs131@fschool.vn'),
  ('ph129@fschool.vn', 'hs132@fschool.vn'),
  ('ph130@fschool.vn', 'hs133@fschool.vn'),
  ('ph131@fschool.vn', 'hs134@fschool.vn')
) AS v(p, s) JOIN dbo.Users p ON p.email = v.p JOIN dbo.Users s ON s.email = v.s;

INSERT dbo.Schedule (teacherId, className, subject, dayOfWeek, period, startTime, endTime, room, mode, content, prep, note)
SELECT t.id, v.c, v.sub, v.d, v.p, CHOOSE(v.p, '07:30', '08:25', '09:20', '10:15', '11:10'), CHOOSE(v.p, '08:15', '09:10', '10:05', '11:00', '11:55'),
       CASE WHEN v.sub = N'Thể dục' THEN N'Sân thể chất' WHEN v.c = N'10A2' THEN CONCAT(N'P.20', v.p) ELSE CONCAT(N'P.10', v.p) END,
       N'Trực tiếp', CONCAT(N'Bài học môn ', v.sub), N'Sách giáo khoa và vở ghi', NULL
FROM (VALUES
  (N'10A2', N'Toán', 1, 1, 'huong.nt@fschool.vn'),
  (N'10A2', N'Văn', 1, 2, 'trang.lt@fschool.vn'),
  (N'10A2', N'Hóa', 1, 3, 'chau.hm@fschool.vn'),
  (N'10A2', N'Anh', 1, 4, 'ducanh.p@fschool.vn'),
  (N'10A2', N'Anh', 1, 5, 'ducanh.p@fschool.vn'),
  (N'10A2', N'Văn', 2, 1, 'trang.lt@fschool.vn'),
  (N'10A2', N'Sử', 2, 2, 'trang.lt@fschool.vn'),
  (N'10A2', N'Lý', 2, 3, 'bao.tq@fschool.vn'),
  (N'10A2', N'Văn', 2, 4, 'trang.lt@fschool.vn'),
  (N'10A2', N'Lý', 2, 5, 'bao.tq@fschool.vn'),
  (N'10A2', N'Toán', 3, 1, 'huong.nt@fschool.vn'),
  (N'10A2', N'Hóa', 3, 2, 'chau.hm@fschool.vn'),
  (N'10A2', N'Toán', 3, 3, 'huong.nt@fschool.vn'),
  (N'10A2', N'Anh', 3, 4, 'ducanh.p@fschool.vn'),
  (N'10A2', N'Thể dục', 3, 5, 'hung.dv@fschool.vn'),
  (N'10A2', N'Thể dục', 4, 1, 'hung.dv@fschool.vn'),
  (N'10A2', N'GDCD', 4, 2, 'trang.lt@fschool.vn'),
  (N'10A2', N'Sử', 4, 3, 'trang.lt@fschool.vn'),
  (N'10A2', N'Tin', 4, 4, 'bao.tq@fschool.vn'),
  (N'10A2', N'Địa', 4, 5, 'ducanh.p@fschool.vn'),
  (N'10A2', N'Sinh', 5, 1, 'chau.hm@fschool.vn'),
  (N'10A2', N'Sinh', 5, 2, 'chau.hm@fschool.vn'),
  (N'10A2', N'Văn', 5, 3, 'trang.lt@fschool.vn'),
  (N'10A2', N'Anh', 5, 4, 'ducanh.p@fschool.vn'),
  (N'10A2', N'Hóa', 5, 5, 'chau.hm@fschool.vn'),
  (N'10A2', N'Sinh', 6, 1, 'chau.hm@fschool.vn'),
  (N'10A2', N'Tin', 6, 2, 'bao.tq@fschool.vn'),
  (N'10A2', N'Địa', 6, 3, 'ducanh.p@fschool.vn'),
  (N'10A2', N'SHL', 6, 4, 'trang.lt@fschool.vn'),
  (N'11A1', N'Lý', 1, 1, 'bao.tq@fschool.vn'),
  (N'11A1', N'Anh', 1, 2, 'ducanh.p@fschool.vn'),
  (N'11A1', N'Thể dục', 1, 3, 'hung.dv@fschool.vn'),
  (N'11A1', N'Sử', 1, 4, 'trang.lt@fschool.vn'),
  (N'11A1', N'Văn', 1, 5, 'trang.lt@fschool.vn'),
  (N'11A1', N'Lý', 2, 1, 'bao.tq@fschool.vn'),
  (N'11A1', N'Tin', 2, 2, 'bao.tq@fschool.vn'),
  (N'11A1', N'Hóa', 2, 3, 'chau.hm@fschool.vn'),
  (N'11A1', N'Hóa', 2, 4, 'chau.hm@fschool.vn'),
  (N'11A1', N'Anh', 2, 5, 'ducanh.p@fschool.vn'),
  (N'11A1', N'Sinh', 3, 1, 'chau.hm@fschool.vn'),
  (N'11A1', N'Toán', 3, 2, 'huong.nt@fschool.vn'),
  (N'11A1', N'Văn', 3, 3, 'trang.lt@fschool.vn'),
  (N'11A1', N'Sinh', 3, 4, 'chau.hm@fschool.vn'),
  (N'11A1', N'GDCD', 3, 5, 'trang.lt@fschool.vn'),
  (N'11A1', N'Sinh', 4, 1, 'chau.hm@fschool.vn'),
  (N'11A1', N'Tin', 4, 2, 'bao.tq@fschool.vn'),
  (N'11A1', N'Anh', 4, 3, 'ducanh.p@fschool.vn'),
  (N'11A1', N'Toán', 4, 4, 'huong.nt@fschool.vn'),
  (N'11A1', N'Thể dục', 4, 5, 'hung.dv@fschool.vn'),
  (N'11A1', N'Sử', 5, 1, 'trang.lt@fschool.vn'),
  (N'11A1', N'Văn', 5, 2, 'trang.lt@fschool.vn'),
  (N'11A1', N'Anh', 5, 3, 'ducanh.p@fschool.vn'),
  (N'11A1', N'Hóa', 5, 4, 'chau.hm@fschool.vn'),
  (N'11A1', N'Văn', 5, 5, 'trang.lt@fschool.vn'),
  (N'11A1', N'Địa', 6, 1, 'ducanh.p@fschool.vn'),
  (N'11A1', N'Địa', 6, 2, 'ducanh.p@fschool.vn'),
  (N'11A1', N'Toán', 6, 3, 'huong.nt@fschool.vn'),
  (N'11A1', N'SHL', 6, 4, 'ducanh.p@fschool.vn')
) AS v(c, sub, d, p, t) JOIN dbo.Users t ON t.email = v.t;

-- Grades: 8 subjects x 6 scores for every new student. Each student has an ability level; scores vary around it (0.5 steps).
DECLARE @subj TABLE (subject NVARCHAR(100), short NVARCHAR(20));
INSERT @subj VALUES (N'Toán', N'Toán'), (N'Ngữ văn', N'Văn'), (N'Tiếng Anh', N'Anh'), (N'Vật lý', N'Lý'), (N'Hóa học', N'Hóa'), (N'Sinh học', N'Sinh'), (N'Lịch sử', N'Sử'), (N'Tin học', N'Tin');
DECLARE @kinds TABLE (n INT, type NVARCHAR(20), weight TINYINT, gradeDate DATE);
INSERT @kinds VALUES (1, N'Miệng', 1, '2026-09-10'), (2, N'15 phút', 1, '2026-09-24'), (3, N'15 phút', 1, '2026-10-08'), (4, N'1 tiết', 2, '2026-10-15'), (5, N'Giữa kỳ', 2, '2026-10-28'), (6, N'Cuối kỳ', 3, '2026-12-20');
DECLARE @new TABLE (id INT, email NVARCHAR(150), className NVARCHAR(20), ability DECIMAL(4,2));
INSERT @new SELECT id, email, className, 5.0 + (ABS(CHECKSUM(email)) % 40) / 10.0 FROM dbo.Users WHERE role = 'HS' AND email LIKE 'hs1[0-9][0-9]@fschool.vn';
INSERT dbo.Grade (studentId, subject, score, term, type, weight, gradeDate)
SELECT s.id, m.subject, x.score, N'HK1', k.type, k.weight, k.gradeDate
FROM @new s CROSS JOIN @subj m CROSS JOIN @kinds k
CROSS APPLY (SELECT CAST(ROUND((s.ability + (ABS(CHECKSUM(s.email, m.subject, k.n)) % 31 - 12) / 10.0) * 2, 0) / 2 AS DECIMAL(4,2)) AS raw) r
CROSS APPLY (SELECT CASE WHEN r.raw > 10 THEN 10 WHEN r.raw < 2 THEN 2 ELSE r.raw END AS score) x;
-- Remark by the teacher who teaches that subject to the class (from the timetable).
INSERT dbo.GradeRemark (studentId, subject, term, teacherId, comment)
SELECT s.id, m.subject, N'HK1', t.teacherId,
       CASE WHEN s.ability >= 8 THEN N'Em học tốt, tiếp thu nhanh, cần giữ vững phong độ.'
            WHEN s.ability >= 6.5 THEN N'Em chăm chỉ, cần luyện thêm bài tập nâng cao.'
            ELSE N'Em cần tập trung hơn trong giờ học và làm bài tập về nhà đầy đủ.' END
FROM @new s CROSS JOIN @subj m
CROSS APPLY (SELECT TOP 1 sc.teacherId FROM dbo.Schedule sc WHERE sc.className = s.className AND sc.subject = m.short ORDER BY sc.id) t;
INSERT dbo.TermSummary (studentId, term, conduct)
SELECT id, N'HK1', CASE WHEN ABS(CHECKSUM(email, 'hk')) % 6 = 0 THEN N'Khá' ELSE N'Tốt' END FROM @new;

INSERT dbo.Requests (studentId, createdBy, type, fromDate, toDate, reason, status, teacherComment, handledBy, handledAt, createdAt)
SELECT s.id, c.id, v.type, v.f, v.t, v.reason, v.status, v.cmt, h.id, v.ha, v.ca FROM (VALUES
  ('hs127@fschool.vn', 'hs127@fschool.vn', N'Xin phép đi trễ', '2026-09-01', '2026-09-01', N'Con đi tiêm phòng theo lịch của phường.', 'pending', NULL, NULL, NULL, '2026-09-01T06:00:00'),
  ('hs132@fschool.vn', 'ph129@fschool.vn', N'Xin phép đi trễ', '2026-10-04', '2026-10-04', N'Xe đưa đón bị hỏng, con sẽ đến muộn tiết 1.', 'approved', N'Cô đã ghi nhận, chúc em mau khỏe.', 'ducanh.p@fschool.vn', '2026-10-04T12:30:00', '2026-10-04T07:07:00'),
  ('hs112@fschool.vn', 'ph112@fschool.vn', N'Xin đổi chỗ ngồi', '2026-11-05', NULL, N'Con bị cận, xin cho con ngồi bàn đầu.', 'approved', N'Cô đã ghi nhận, chúc em mau khỏe.', 'trang.lt@fschool.vn', '2026-11-05T13:30:00', '2026-11-05T08:14:00'),
  ('hs133@fschool.vn', 'ph130@fschool.vn', N'Xin nghỉ học', '2026-09-10', '2026-09-10', N'Con bị đau bụng, cần nghỉ ngơi theo chỉ định bác sĩ.', 'pending', NULL, NULL, NULL, '2026-09-10T09:21:00'),
  ('hs114@fschool.vn', 'hs114@fschool.vn', N'Xin nghỉ học', '2026-10-13', '2026-10-13', N'Con bị cảm sốt, gia đình xin cho con nghỉ để đi khám.', 'approved', N'Đồng ý, em nhớ bổ sung giấy khám bệnh.', 'trang.lt@fschool.vn', '2026-10-13T15:30:00', '2026-10-13T06:28:00'),
  ('hs124@fschool.vn', 'ph123@fschool.vn', N'Xin phép đi trễ', '2026-11-05', '2026-11-05', N'Xe đưa đón bị hỏng, con sẽ đến muộn tiết 1.', 'rejected', N'Cô sẽ đổi chỗ vào đầu tháng sau khi xếp lại sơ đồ lớp.', 'ducanh.p@fschool.vn', '2026-11-05T11:30:00', '2026-11-05T07:35:00'),
  ('hs102@fschool.vn', 'ph102@fschool.vn', N'Xin đổi chỗ ngồi', '2026-09-19', NULL, N'Con bị cận, xin cho con ngồi bàn đầu.', 'pending', NULL, NULL, NULL, '2026-09-19T08:42:00'),
  ('hs107@fschool.vn', 'ph107@fschool.vn', N'Xin đổi chỗ ngồi', '2026-10-22', NULL, N'Con khó nghe giảng ở cuối lớp, xin chuyển lên trên.', 'approved', N'Đồng ý. Em nhớ chép bài đầy đủ.', 'gv@fschool.vn', '2026-10-22T13:30:00', '2026-10-22T09:49:00'),
  ('hs111@fschool.vn', 'hs111@fschool.vn', N'Xin nghỉ học', '2026-11-05', '2026-11-05', N'Gia đình có việc hiếu ở quê, xin cho con nghỉ học.', 'approved', N'Cô đã ghi nhận, chúc em mau khỏe.', 'trang.lt@fschool.vn', '2026-11-05T14:30:00', '2026-11-05T06:56:00'),
  ('hs116@fschool.vn', 'ph115@fschool.vn', N'Xin nghỉ học', '2026-09-28', '2026-09-28', N'Gia đình có việc hiếu ở quê, xin cho con nghỉ học.', 'pending', NULL, NULL, NULL, '2026-09-28T07:03:00'),
  ('hs115@fschool.vn', 'ph114@fschool.vn', N'Xin phép đi trễ', '2026-10-03', '2026-10-03', N'Xe đưa đón bị hỏng, con sẽ đến muộn tiết 1.', 'approved', N'Cô đã ghi nhận, chúc em mau khỏe.', 'trang.lt@fschool.vn', '2026-10-03T11:30:00', '2026-10-03T08:10:00'),
  ('hs110@fschool.vn', 'ph110@fschool.vn', N'Xin đổi chỗ ngồi', '2026-11-05', NULL, N'Con bị cận, xin cho con ngồi bàn đầu.', 'rejected', N'Cô sẽ đổi chỗ vào đầu tháng sau khi xếp lại sơ đồ lớp.', 'gv@fschool.vn', '2026-11-05T12:30:00', '2026-11-05T09:17:00'),
  ('hs104@fschool.vn', 'hs104@fschool.vn', N'Xin nghỉ học', '2026-09-09', '2026-09-11', N'Gia đình có việc hiếu ở quê, xin cho con nghỉ học.', 'pending', NULL, NULL, NULL, '2026-09-09T06:24:00'),
  ('hs131@fschool.vn', 'ph114@fschool.vn', N'Xin nghỉ học', '2026-10-12', '2026-10-12', N'Con bị cảm sốt, gia đình xin cho con nghỉ để đi khám.', 'approved', N'Cô đã ghi nhận, chúc em mau khỏe.', 'ducanh.p@fschool.vn', '2026-10-12T14:30:00', '2026-10-12T07:31:00'),
  ('hs108@fschool.vn', 'ph108@fschool.vn', N'Xin nghỉ học', '2026-11-05', '2026-11-05', N'Gia đình có việc hiếu ở quê, xin cho con nghỉ học.', 'approved', N'Cô đã ghi nhận, chúc em mau khỏe.', 'gv@fschool.vn', '2026-11-05T15:30:00', '2026-11-05T08:38:00'),
  ('hs113@fschool.vn', 'ph101@fschool.vn', N'Xin phép đi trễ', '2026-09-18', '2026-09-18', N'Con đi tiêm phòng theo lịch của phường.', 'pending', NULL, NULL, NULL, '2026-09-18T09:45:00'),
  ('hs105@fschool.vn', 'hs105@fschool.vn', N'Xin phép đi trễ', '2026-10-21', '2026-10-21', N'Con đi tiêm phòng theo lịch của phường.', 'approved', N'Cô đã ghi nhận, chúc em mau khỏe.', 'gv@fschool.vn', '2026-10-21T12:30:00', '2026-10-21T06:52:00'),
  ('hs125@fschool.vn', 'ph124@fschool.vn', N'Xin phép đi trễ', '2026-11-05', '2026-11-05', N'Con có lịch khám mắt buổi sáng.', 'rejected', N'Tuần này lớp có kiểm tra định kỳ, em sắp xếp lại lịch nhé.', 'ducanh.p@fschool.vn', '2026-11-05T13:30:00', '2026-11-05T07:59:00')
) AS v(s, cb, type, f, t, reason, status, cmt, h, ha, ca)
JOIN dbo.Users s ON s.email = v.s JOIN dbo.Users c ON c.email = v.cb LEFT JOIN dbo.Users h ON h.email = v.h;

INSERT dbo.ClubMembers (clubId, userId, status) SELECT c.id, u.id, v.st FROM (VALUES
  (N'CLB Bóng đá', 'hs101@fschool.vn', 'approved'),
  (N'CLB Âm nhạc', 'hs102@fschool.vn', 'pending'),
  (N'CLB Lập trình', 'hs103@fschool.vn', 'pending'),
  (N'CLB Bóng rổ', 'hs104@fschool.vn', 'approved'),
  (N'CLB Âm nhạc', 'hs105@fschool.vn', 'approved'),
  (N'CLB Bóng đá', 'hs105@fschool.vn', 'pending'),
  (N'CLB Mỹ thuật', 'hs106@fschool.vn', 'approved'),
  (N'CLB Mỹ thuật', 'hs108@fschool.vn', 'approved'),
  (N'CLB Bóng đá', 'hs108@fschool.vn', 'approved'),
  (N'CLB Lập trình', 'hs109@fschool.vn', 'pending'),
  (N'CLB Bóng rổ', 'hs112@fschool.vn', 'approved'),
  (N'CLB Mỹ thuật', 'hs113@fschool.vn', 'pending'),
  (N'CLB Bóng rổ', 'hs113@fschool.vn', 'approved'),
  (N'CLB Bóng rổ', 'hs114@fschool.vn', 'pending'),
  (N'CLB Bóng rổ', 'hs115@fschool.vn', 'pending'),
  (N'CLB Mỹ thuật', 'hs116@fschool.vn', 'approved'),
  (N'CLB Lập trình', 'hs116@fschool.vn', 'pending'),
  (N'CLB Lập trình', 'hs117@fschool.vn', 'pending'),
  (N'CLB Lập trình', 'hs119@fschool.vn', 'pending'),
  (N'CLB Lập trình', 'hs120@fschool.vn', 'pending'),
  (N'CLB Mỹ thuật', 'hs122@fschool.vn', 'approved'),
  (N'CLB Bóng đá', 'hs122@fschool.vn', 'approved'),
  (N'CLB Bóng đá', 'hs124@fschool.vn', 'approved'),
  (N'CLB Lập trình', 'hs125@fschool.vn', 'pending'),
  (N'CLB Mỹ thuật', 'hs126@fschool.vn', 'approved'),
  (N'CLB Bóng đá', 'hs126@fschool.vn', 'pending'),
  (N'CLB Âm nhạc', 'hs127@fschool.vn', 'pending'),
  (N'CLB Mỹ thuật', 'hs128@fschool.vn', 'pending'),
  (N'CLB Lập trình', 'hs128@fschool.vn', 'pending'),
  (N'CLB Lập trình', 'hs129@fschool.vn', 'pending'),
  (N'CLB Âm nhạc', 'hs131@fschool.vn', 'approved'),
  (N'CLB Lập trình', 'hs132@fschool.vn', 'pending'),
  (N'CLB Bóng rổ', 'hs134@fschool.vn', 'approved')
) AS v(club, u, st) JOIN dbo.Clubs c ON c.name = v.club JOIN dbo.Users u ON u.email = v.u;
COMMIT;
PRINT 'Demo extra data added.';
