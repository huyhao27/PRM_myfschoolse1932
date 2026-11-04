-- Demo data for phase 2. Idempotent: each block runs only when its table is empty. Needs the users from init.js.
UPDATE dbo.Users SET className = N'10A1' WHERE email IN ('hs@fschool.vn', 'hs2@fschool.vn') AND className IS NULL;
IF NOT EXISTS (SELECT 1 FROM dbo.ParentStudent)
  INSERT dbo.ParentStudent (parentId, studentId)
  SELECT p.id, s.id FROM dbo.Users p CROSS JOIN dbo.Users s
  WHERE p.email = 'ph@fschool.vn' AND s.email IN ('hs@fschool.vn', 'hs2@fschool.vn');
GO
IF NOT EXISTS (SELECT 1 FROM dbo.Schedule)
BEGIN
  DECLARE @gv INT = (SELECT id FROM dbo.Users WHERE email = 'gv@fschool.vn');
  DECLARE @gv2 INT = (SELECT id FROM dbo.Users WHERE email = 'gv2@fschool.vn');
  INSERT dbo.Schedule (teacherId, className, subject, dayOfWeek, period, startTime, endTime, room, mode, content, prep, note)
  SELECT CASE WHEN t.subject IN (N'Toán', N'Lý', N'Hóa', N'Tin', N'Thể dục') THEN @gv ELSE @gv2 END,
         N'10A1', t.subject, t.d, t.p,
         CHOOSE(t.p, '07:30', '08:25', '09:20', '10:15', '11:10'),
         CHOOSE(t.p, '08:15', '09:10', '10:05', '11:00', '11:55'),
         CASE WHEN t.subject = N'Thể dục' THEN N'Sân thể chất' ELSE CONCAT(N'P.30', t.p) END,
         N'Trực tiếp', CONCAT(N'Bài học môn ', t.subject), N'Sách giáo khoa và vở ghi',
         CASE WHEN t.subject = N'Anh' AND t.d = 3 AND t.p = 1 THEN N'Kiểm tra 15 phút đầu giờ. Mang theo vở bài tập.' END
  FROM (VALUES
    (1,1,N'Toán'),(2,1,N'Văn'),(3,1,N'Anh'),(4,1,N'Toán'),(5,1,N'Lý'),(6,1,N'Văn'),
    (1,2,N'Anh'),(2,2,N'Toán'),(3,2,N'Văn'),(4,2,N'Hóa'),(5,2,N'Sinh'),(6,2,N'Anh'),
    (1,3,N'Lý'),(2,3,N'Sinh'),(3,3,N'Sử'),(4,3,N'Văn'),(5,3,N'Hóa'),(6,3,N'GDCD'),
    (1,4,N'Địa'),(2,4,N'Hóa'),(3,4,N'Anh'),(4,4,N'Tin'),(5,4,N'Sử'),(6,4,N'SHL'),
    (1,5,N'Thể dục'),(2,5,N'Tin'),(3,5,N'Địa'),(4,5,N'Sinh'),(5,5,N'Thể dục')
  ) AS t(d, p, subject);
END
GO
IF NOT EXISTS (SELECT 1 FROM dbo.Grade)
BEGIN
  -- six scores per subject: oral, 15 min, 15 min, 1 period, midterm, final
  DECLARE @marks TABLE (subject NVARCHAR(100), a DECIMAL(4,2), b DECIMAL(4,2), c DECIMAL(4,2), d DECIMAL(4,2), e DECIMAL(4,2), f DECIMAL(4,2));
  INSERT @marks VALUES
    (N'Toán', 9, 8.5, 9, 8.5, 9, 9), (N'Ngữ văn', 7.5, 7.5, 8, 7.5, 7.5, 8),
    (N'Tiếng Anh', 9, 9, 9, 9, 9, 9.5), (N'Vật lý', 8, 8, 8.5, 8, 8, 8.5),
    (N'Hóa học', 7, 7, 7.5, 7, 7, 7.5), (N'Sinh học', 8.5, 8, 8.5, 8.5, 8.5, 8),
    (N'Lịch sử', 8, 8.5, 8, 8, 8, 9), (N'Tin học', 9.5, 9.5, 10, 9.5, 9.5, 10);
  DECLARE @kinds TABLE (n INT, type NVARCHAR(20), weight TINYINT, gradeDate DATE);
  INSERT @kinds VALUES (1, N'Miệng', 1, '2026-09-10'), (2, N'15 phút', 1, '2026-09-24'), (3, N'15 phút', 1, '2026-10-08'),
    (4, N'1 tiết', 2, '2026-10-15'), (5, N'Giữa kỳ', 2, '2026-10-28'), (6, N'Cuối kỳ', 3, '2026-12-20');
  INSERT dbo.Grade (studentId, subject, score, term, type, weight, gradeDate)
  SELECT s.id, m.subject,
         CASE WHEN s.email = 'hs2@fschool.vn' THEN v.score - 0.5 ELSE v.score END,
         N'HK1', k.type, k.weight, k.gradeDate
  FROM dbo.Users s
  CROSS JOIN @marks m
  CROSS APPLY (VALUES (1, m.a), (2, m.b), (3, m.c), (4, m.d), (5, m.e), (6, m.f)) AS v(n, score)
  JOIN @kinds k ON k.n = v.n
  WHERE s.email IN ('hs@fschool.vn', 'hs2@fschool.vn');
  INSERT dbo.GradeRemark (studentId, subject, term, teacherId, comment)
  SELECT s.id, m.subject, N'HK1',
         (SELECT id FROM dbo.Users WHERE email = CASE WHEN m.subject IN (N'Toán', N'Vật lý', N'Hóa học', N'Tin học') THEN 'gv@fschool.vn' ELSE 'gv2@fschool.vn' END),
         CASE WHEN m.subject = N'Toán' THEN N'Em tiếp thu tốt, cần chú ý trình bày bài giải hình học.' ELSE N'Em học tập tích cực, cần phát huy.' END
  FROM dbo.Users s CROSS JOIN @marks m WHERE s.email IN ('hs@fschool.vn', 'hs2@fschool.vn');
  INSERT dbo.TermSummary (studentId, term, conduct)
  SELECT id, N'HK1', N'Tốt' FROM dbo.Users WHERE email IN ('hs@fschool.vn', 'hs2@fschool.vn');
END
GO
IF NOT EXISTS (SELECT 1 FROM dbo.Clubs)
BEGIN
  INSERT dbo.Clubs (name, icon, description, meeting, location, advisor, president, baseMembers) VALUES
    (N'CLB Bóng đá', N'⚽', N'Luyện tập và thi đấu giao hữu cùng các lớp.', N'Sinh hoạt T4, 16:00', N'Sân bóng trường', N'Thầy Đặng Văn Sơn', N'Lê Hoàng Nam (11A1)', 41),
    (N'CLB Âm nhạc', N'♪', N'Hát, chơi nhạc cụ và biểu diễn trong các sự kiện của trường.', N'Sinh hoạt T3, 15:30', N'Phòng âm nhạc', N'Cô Vũ Thu Hà', N'Phạm Gia Hân (11A3)', 28),
    (N'CLB Lập trình', N'</>', N'Nơi học sinh yêu công nghệ cùng học Python, Flutter và tham gia các cuộc thi lập trình.', N'Sinh hoạt T6, 15:30', N'P.401 - Phòng máy', N'Thầy Lê Văn Hùng', N'Trần Minh Quân (11A2)', 56),
    (N'CLB Mỹ thuật', N'✎', N'Vẽ, thiết kế và trang trí các hoạt động của trường.', N'Sinh hoạt T5, 15:30', N'Phòng mỹ thuật', N'Cô Ngô Thanh Mai', N'Đỗ Khánh Linh (11A4)', 19),
    (N'CLB Bóng rổ', N'●', N'Rèn thể lực và tinh thần đồng đội qua các giải đấu nội bộ.', N'Sinh hoạt T2, 16:00', N'Nhà thi đấu', N'Thầy Bùi Quang Huy', N'Nguyễn Tuấn Kiệt (11A1)', 35);
  INSERT dbo.ClubMembers (clubId, userId, status)
  SELECT c.id, u.id, x.status FROM (VALUES (N'CLB Bóng đá', 'approved'), (N'CLB Âm nhạc', 'pending')) AS x(club, status)
  JOIN dbo.Clubs c ON c.name = x.club CROSS JOIN dbo.Users u WHERE u.email = 'hs@fschool.vn';
END
GO
IF NOT EXISTS (SELECT 1 FROM dbo.Requests)
BEGIN
  DECLARE @ph INT = (SELECT id FROM dbo.Users WHERE email = 'ph@fschool.vn');
  DECLARE @hs INT = (SELECT id FROM dbo.Users WHERE email = 'hs@fschool.vn');
  DECLARE @hs2 INT = (SELECT id FROM dbo.Users WHERE email = 'hs2@fschool.vn');
  DECLARE @gv INT = (SELECT id FROM dbo.Users WHERE email = 'gv@fschool.vn');
  INSERT dbo.Requests (studentId, createdBy, type, fromDate, toDate, reason, status, teacherComment, handledBy, handledAt, createdAt) VALUES
    (@hs, @ph, N'Xin nghỉ học', '2026-10-15', '2026-10-16', N'Con bị sốt, xin phép cho con nghỉ học 2 ngày để đi khám và nghỉ ngơi.', 'pending', NULL, NULL, NULL, '2026-10-14T13:15:00'),
    (@hs, @ph, N'Xin nghỉ học', '2026-10-02', '2026-10-02', N'Gia đình có việc đột xuất.', 'approved', N'Đồng ý. Em nhớ chép bài.', @gv, '2026-10-01T09:00:00', '2026-10-01T07:30:00'),
    (@hs2, @ph, N'Xin đổi chỗ ngồi', '2026-09-25', NULL, N'Con khó nhìn bảng ở vị trí hiện tại.', 'rejected', N'Hiện chưa sắp xếp lại được, cô sẽ xem xét vào đầu học kỳ sau.', @gv, '2026-09-26T08:00:00', '2026-09-25T20:00:00'),
    (@hs2, @ph, N'Xin phép đi trễ', '2026-10-12', '2026-10-12', N'Con có lịch khám răng buổi sáng.', 'pending', NULL, NULL, NULL, '2026-10-11T19:00:00');
END
GO
