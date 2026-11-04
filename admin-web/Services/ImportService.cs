using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using MyfschoolWeb.DataAccess;
using MyfschoolWeb.Models;

namespace MyfschoolWeb.Services
{
    /// <summary>
    /// CSV import into SQL Server (Manager only). Each import runs in ONE transaction: rows that fail validation are skipped and listed
    /// in ErrorDetails (with the CSV line number); an unexpected database error rolls the whole import back.
    /// Idempotent: users are matched by phone/email, lessons by class+day+period, grades by student+subject+term+type+date.
    /// </summary>
    public class ImportService
    {
        public const string StudentsTemplate =
            "fullName,className,phone,email,role,parentPhone\n" +
            "Nguyễn Văn An,10A1,0912000001,an.nv@fschool.vn,HS,0901234567\n" +
            "Trần Thị Bình,10A1,0912000002,binh.tt@fschool.vn,HS,\n";

        public const string SchedulesTemplate =
            "className,subject,dayOfWeek,period,teacher,room,mode,content,prep,note\n" +
            "10A1,Toán,1,1,gv@fschool.vn,P.301,Trực tiếp,Bài học môn Toán,Sách giáo khoa và vở ghi,\n" +
            "10A1,Văn,1,2,gv2@fschool.vn,P.302,Trực tiếp,Bài học môn Văn,Sách giáo khoa,Mang theo vở bài tập\n";

        public const string GradesTemplate =
            "student,subject,term,type,score,weight,gradeDate\n" +
            "hs@fschool.vn,Toán,HK1,15 phút,8.5,1,2026-10-08\n";

        // ------------------------------------------------------------------ CSV parsing

        private class Csv
        {
            public List<string> Headers = new List<string>();
            public List<string[]> Rows = new List<string[]>();
            public List<int> Lines = new List<int>();

            public string Get(string[] row, params string[] aliases)
            {
                foreach (var a in aliases)
                {
                    int i = Headers.IndexOf(a);
                    if (i >= 0 && i < row.Length && !string.IsNullOrWhiteSpace(row[i])) return row[i].Trim();
                }
                return null;
            }

            public bool Has(params string[] aliases) { return aliases.Any(a => Headers.Contains(a)); }
        }

        private static string NormHeader(string h)
        {
            return (h ?? "").Trim().Trim('﻿').Replace("_", "").Replace(" ", "").ToLowerInvariant();
        }

        // RFC4180-ish: quoted fields, "" escapes, commas/newlines inside quotes. Blank lines are skipped.
        private static Csv Parse(string text)
        {
            var csv = new Csv();
            var cur = new StringBuilder();
            var fields = new List<string>();
            bool inQ = false, any = false;
            int line = 1, rowStart = 1;
            Action endRow = () =>
            {
                fields.Add(cur.ToString()); cur.Length = 0;
                bool blank = fields.All(f => f.Trim().Length == 0);
                if (!blank)
                {
                    if (csv.Headers.Count == 0) csv.Headers = fields.Select(NormHeader).ToList();
                    else { csv.Rows.Add(fields.ToArray()); csv.Lines.Add(rowStart); }
                }
                fields.Clear(); any = false;
            };
            for (int i = 0; i < text.Length; i++)
            {
                char c = text[i];
                if (!any) rowStart = line;
                if (inQ)
                {
                    if (c == '"') { if (i + 1 < text.Length && text[i + 1] == '"') { cur.Append('"'); i++; } else inQ = false; }
                    else { cur.Append(c); if (c == '\n') line++; }
                    continue;
                }
                if (c == '"') { inQ = true; any = true; }
                else if (c == ',') { fields.Add(cur.ToString()); cur.Length = 0; any = true; }
                else if (c == '\r') { }
                else if (c == '\n') { endRow(); line++; }
                else { cur.Append(c); any = true; }
            }
            if (any || cur.Length > 0 || fields.Count > 0) endRow();
            return csv;
        }

        private static ImportResultModel Fail(string msg) { return new ImportResultModel { Success = false, Message = msg }; }

        // Common start: permission, non-empty, parse, required columns. Returns null when OK.
        private static ImportResultModel Prepare(UserModel actor, string content, out Csv csv, string[][] requiredAnyOf, string requiredText)
        {
            csv = null;
            if (actor == null || !actor.IsManager) return Fail("Từ chối quyền: chỉ Quản lý mới được import dữ liệu.");
            if (string.IsNullOrWhiteSpace(content)) return Fail("Nội dung tệp CSV trống!");
            csv = Parse(content);
            if (csv.Headers.Count == 0) return Fail("Tệp không có dòng tiêu đề (header).");
            foreach (var group in requiredAnyOf)
                if (!csv.Has(group))
                    return Fail("Thiếu cột bắt buộc trong dòng tiêu đề. Cần: " + requiredText + ".");
            if (csv.Rows.Count == 0) return Fail("Tệp chỉ có dòng tiêu đề, không có dữ liệu.");
            if (csv.Rows.Count > 5000) return Fail("Tệp quá lớn (tối đa 5000 dòng mỗi lần).");
            return null;
        }

        private static void Finish(ImportResultModel r, string what)
        {
            r.Success = r.FailedCount == 0;
            r.Message = "Import " + what + ": " + r.TotalProcessed + " dòng (" + r.InsertedCount + " thêm mới, " + r.UpdatedCount + " cập nhật, " + r.FailedCount + " lỗi bị bỏ qua).";
        }

        private static ImportResultModel Rolled(string what, Exception ex)
        {
            return Fail("Import " + what + " thất bại, toàn bộ thay đổi đã được hoàn tác. Lý do: " + ex.Message);
        }

        // ------------------------------------------------------------------ students / users

        private static string RoleCode(string raw)
        {
            switch ((raw ?? "HS").Trim().ToUpperInvariant())
            {
                case "": case "HS": case "STUDENT": return Roles.Student;
                case "GV": case "TEACHER": return Roles.Teacher;
                case "PH": case "PARENT": return Roles.Parent;
                default: return null;   // Manager accounts cannot be created by CSV
            }
        }

        private static readonly Func<IDataRecord, int> IdMap = r => Convert.ToInt32(r.GetValue(0));

        /// <summary>Columns (any order, case-insensitive): fullName|name, className, phone|phoneNumber, email, role (HS default, GV, PH), parentPhone (links a HS to an existing PH).</summary>
        public ImportResultModel ImportStudentsFromCsv(UserModel actor, string csvContent)
        {
            Csv csv;
            var bad = Prepare(actor, csvContent, out csv, new[] { new[] { "fullname", "name" }, new[] { "phone", "phonenumber", "email" } }, "fullName và phone (hoặc email)");
            if (bad != null) return bad;
            var result = new ImportResultModel();
            try
            {
                SqlDb.Transaction(tx =>
                {
                    for (int i = 0; i < csv.Rows.Count; i++)
                    {
                        var row = csv.Rows[i];
                        int line = csv.Lines[i];
                        result.TotalProcessed++;
                        string err = ImportUserRow(tx, csv, row, result);
                        if (err != null) { result.FailedCount++; result.ErrorDetails.Add("Dòng " + line + ": " + err); }
                    }
                });
            }
            catch (Exception ex) { return Rolled("tài khoản", ex); }
            Finish(result, "tài khoản");
            return result;
        }

        private string ImportUserRow(SqlTx tx, Csv csv, string[] row, ImportResultModel result)
        {
            string name = csv.Get(row, "fullname", "name");
            string cls = csv.Get(row, "classname", "class");
            string phone = StudentService.NormalizePhone(csv.Get(row, "phone", "phonenumber"));
            string email = csv.Get(row, "email");
            if (email != null) email = email.ToLowerInvariant();
            string role = RoleCode(csv.Get(row, "role"));
            string parentRaw = csv.Get(row, "parentphone", "parent");

            if (role == null) return "Vai trò không hợp lệ (chỉ HS, GV hoặc PH).";
            if (phone == null && email == null) return "Cần ít nhất số điện thoại hoặc email.";
            string v = StudentService.ValidateFields(name, phone, email, cls);
            if (v != null) return v;
            if (role == Roles.Student && cls == null) return "Học sinh cần có lớp (className).";

            int? byPhone = phone == null ? (int?)null : tx.Query("SELECT id FROM dbo.Users WHERE phone = @p", IdMap, SqlDb.P("@p", phone)).Cast<int?>().FirstOrDefault();
            int? byEmail = email == null ? (int?)null : tx.Query("SELECT id FROM dbo.Users WHERE email = @e", IdMap, SqlDb.P("@e", email)).Cast<int?>().FirstOrDefault();
            if (byPhone.HasValue && byEmail.HasValue && byPhone.Value != byEmail.Value) return "Số điện thoại và email thuộc hai tài khoản khác nhau.";
            int? existing = byPhone ?? byEmail;

            int? parentId = null;
            if (parentRaw != null)
            {
                if (role != Roles.Student) return "parentPhone chỉ dùng cho học sinh (HS).";
                string pp = StudentService.NormalizePhone(parentRaw);
                parentId = tx.Query("SELECT id FROM dbo.Users WHERE role = 'PH' AND (phone = @p OR email = @e)", IdMap, SqlDb.P("@p", pp), SqlDb.P("@e", parentRaw.ToLowerInvariant())).Cast<int?>().FirstOrDefault();
                if (!parentId.HasValue) return "Không tìm thấy tài khoản phụ huynh (PH) '" + parentRaw + "'.";
            }

            int id;
            if (existing.HasValue)
            {
                id = existing.Value;
                string oldRole = tx.Scalar<string>("SELECT role FROM dbo.Users WHERE id = @id", SqlDb.P("@id", id));
                if (oldRole == Roles.Manager) return "Không được sửa tài khoản Quản lý bằng import.";
                if (oldRole != role && csv.Get(row, "role") != null) return "Tài khoản đã tồn tại với vai trò " + oldRole + " (không đổi vai trò bằng import).";
                tx.Execute("UPDATE dbo.Users SET name = @n, className = COALESCE(@c, className), phone = COALESCE(@p, phone), email = COALESCE(@e, email) WHERE id = @id",
                    SqlDb.P("@n", name.Trim()), SqlDb.P("@c", cls), SqlDb.P("@p", phone), SqlDb.P("@e", email), SqlDb.P("@id", id));
                result.UpdatedCount++;
                result.ImportedItems.Add("Cập nhật: " + name.Trim() + " (" + (phone ?? email) + ")");
            }
            else
            {
                string hash = BCrypt.Net.BCrypt.HashPassword("123456", 10);
                id = tx.Scalar<int>(
                    @"INSERT INTO dbo.Users (name, email, phone, passwordHash, role, className) OUTPUT INSERTED.id VALUES (@n, @e, @p, @h, @r, @c)",
                    SqlDb.P("@n", name.Trim()), SqlDb.P("@e", email), SqlDb.P("@p", phone), SqlDb.P("@h", hash), SqlDb.P("@r", role), SqlDb.P("@c", cls));
                result.InsertedCount++;
                result.ImportedItems.Add("Thêm mới: " + name.Trim() + " (" + (phone ?? email) + ", " + role + ", mật khẩu mặc định 123456)");
            }
            if (parentId.HasValue)
                tx.Execute("IF NOT EXISTS (SELECT 1 FROM dbo.ParentStudent WHERE parentId = @p AND studentId = @s) INSERT dbo.ParentStudent (parentId, studentId) VALUES (@p, @s)",
                    SqlDb.P("@p", parentId.Value), SqlDb.P("@s", id));
            return null;
        }

        // ------------------------------------------------------------------ timetable

        /// <summary>Columns: className, subject|subjectName, dayOfWeek (1..7, T2..T7, CN), period|slotNumber (1..8), teacher (GV phone/email/name; also teacherPhone/teacherEmail/teacherName), room, mode, content, prep, note. Times follow the bell schedule.</summary>
        public ImportResultModel ImportSchedulesFromCsv(UserModel actor, string csvContent)
        {
            Csv csv;
            var bad = Prepare(actor, csvContent, out csv,
                new[] { new[] { "classname", "class" }, new[] { "subject", "subjectname" }, new[] { "dayofweek", "day" }, new[] { "period", "slotnumber", "slot" }, new[] { "teacher", "teacheremail", "teacherphone", "teachername" } },
                "className, subject, dayOfWeek, period, teacher");
            if (bad != null) return bad;
            var result = new ImportResultModel();
            try
            {
                SqlDb.Transaction(tx =>
                {
                    for (int i = 0; i < csv.Rows.Count; i++)
                    {
                        result.TotalProcessed++;
                        string err = ImportLessonRow(tx, csv, csv.Rows[i], result);
                        if (err != null) { result.FailedCount++; result.ErrorDetails.Add("Dòng " + csv.Lines[i] + ": " + err); }
                    }
                });
            }
            catch (Exception ex) { return Rolled("thời khóa biểu", ex); }
            Finish(result, "thời khóa biểu");
            return result;
        }

        private string ImportLessonRow(SqlTx tx, Csv csv, string[] row, ImportResultModel result)
        {
            var m = new ScheduleModel
            {
                ClassName = csv.Get(row, "classname", "class"),
                Subject = csv.Get(row, "subject", "subjectname"),
                Room = csv.Get(row, "room"), Mode = csv.Get(row, "mode"), Content = csv.Get(row, "content"),
                Prep = csv.Get(row, "prep"), Note = csv.Get(row, "note")
            };
            m.DayOfWeek = ScheduleService.ParseDay(csv.Get(row, "dayofweek", "day"));
            int period; int.TryParse(csv.Get(row, "period", "slotnumber", "slot") ?? "", out period); m.Period = period;
            string t = csv.Get(row, "teacher", "teacheremail", "teacherphone", "teachername");
            if (string.IsNullOrWhiteSpace(m.ClassName) || string.IsNullOrWhiteSpace(m.Subject)) return "Thiếu lớp hoặc môn học.";
            if (m.DayOfWeek == 0) return "Thứ trong tuần không hợp lệ (dùng 1-7, T2-T7 hoặc CN).";
            if (m.Period < 1 || m.Period > ScheduleService.MaxPeriod) return "Tiết học phải từ 1 đến " + ScheduleService.MaxPeriod + ".";
            if (t == null) return "Thiếu giáo viên.";
            m.ClassName = m.ClassName.Trim(); m.Subject = m.Subject.Trim();
            if (m.ClassName.Length > 20) return "Tên lớp tối đa 20 ký tự.";
            if (m.Subject.Length > 100) return "Môn học tối đa 100 ký tự.";
            if (m.Room != null && m.Room.Length > 30) return "Phòng học tối đa 30 ký tự.";

            string phone = StudentService.NormalizePhone(t);
            var teachers = tx.Query("SELECT id FROM dbo.Users WHERE role = 'GV' AND (email = @e OR phone = @p)", IdMap, SqlDb.P("@e", t.ToLowerInvariant()), SqlDb.P("@p", phone));
            if (teachers.Count == 0) teachers = tx.Query("SELECT id FROM dbo.Users WHERE role = 'GV' AND name = @n", IdMap, SqlDb.P("@n", t));
            if (teachers.Count == 0) return "Không tìm thấy giáo viên (GV) '" + t + "'.";
            if (teachers.Count > 1) return "Có nhiều giáo viên trùng tên '" + t + "', hãy dùng số điện thoại hoặc email.";
            m.TeacherId = teachers[0];

            m.StartTime = ScheduleService.PeriodStart(m.Period); m.EndTime = ScheduleService.PeriodEnd(m.Period);
            Clip(m);
            string busy = tx.Query("SELECT TOP 1 className FROM dbo.Schedule WHERE teacherId = @t AND dayOfWeek = @d AND period = @p AND className <> @c",
                r => r.GetString(0), SqlDb.P("@t", m.TeacherId), SqlDb.P("@d", m.DayOfWeek), SqlDb.P("@p", m.Period), SqlDb.P("@c", m.ClassName)).FirstOrDefault();
            if (busy != null) return "Giáo viên đã có tiết " + m.Period + " " + ScheduleService.DayName(m.DayOfWeek) + " ở lớp " + busy + ".";

            int? existing = tx.Query("SELECT id FROM dbo.Schedule WHERE className = @c AND dayOfWeek = @d AND period = @p", IdMap,
                SqlDb.P("@c", m.ClassName), SqlDb.P("@d", m.DayOfWeek), SqlDb.P("@p", m.Period)).Cast<int?>().FirstOrDefault();
            string label = m.ClassName + " " + ScheduleService.DayName(m.DayOfWeek) + " tiết " + m.Period + " - " + m.Subject;
            if (existing.HasValue)
            {
                m.Id = existing.Value;
                tx.Execute(@"UPDATE dbo.Schedule SET teacherId=@t, className=@c, subject=@s, dayOfWeek=@d, period=@p, startTime=@st, endTime=@et,
                             room=@r, mode=@m, content=@ct, prep=@pr, note=@n WHERE id=@id", ScheduleService.Params(m, true));
                result.UpdatedCount++; result.ImportedItems.Add("Cập nhật: " + label);
            }
            else
            {
                tx.Execute(@"INSERT INTO dbo.Schedule (teacherId, className, subject, dayOfWeek, period, startTime, endTime, room, mode, content, prep, note)
                             VALUES (@t, @c, @s, @d, @p, @st, @et, @r, @m, @ct, @pr, @n)", ScheduleService.Params(m, false));
                result.InsertedCount++; result.ImportedItems.Add("Thêm mới: " + label);
            }
            return null;
        }

        private static void Clip(ScheduleModel m)
        {
            Func<string, int, string> c = (s, n) => string.IsNullOrWhiteSpace(s) ? null : (s.Trim().Length > n ? s.Trim().Substring(0, n) : s.Trim());
            m.Room = c(m.Room, 30); m.Mode = c(m.Mode, 30); m.Content = c(m.Content, 200); m.Prep = c(m.Prep, 200); m.Note = c(m.Note, 300);
        }

        // ------------------------------------------------------------------ grades (simple bulk import)

        private static int DefaultWeight(string type)
        {
            switch ((type ?? "").Trim().ToLowerInvariant())
            {
                case "1 tiết": case "giữa kỳ": return 2;
                case "cuối kỳ": return 3;
                default: return 1;
            }
        }

        /// <summary>Columns: student (HS phone/email), subject, term, type (Miệng, 15 phút, 1 tiết, Giữa kỳ, Cuối kỳ), score 0-10, weight (optional), gradeDate (yyyy-MM-dd or dd/MM/yyyy, optional).</summary>
        public ImportResultModel ImportGradesFromCsv(UserModel actor, string csvContent)
        {
            Csv csv;
            var bad = Prepare(actor, csvContent, out csv,
                new[] { new[] { "student", "studentphone", "studentemail", "phone", "email" }, new[] { "subject", "subjectname" }, new[] { "score" } },
                "student, subject, score");
            if (bad != null) return bad;
            var result = new ImportResultModel();
            try
            {
                SqlDb.Transaction(tx =>
                {
                    for (int i = 0; i < csv.Rows.Count; i++)
                    {
                        result.TotalProcessed++;
                        string err = ImportGradeRow(tx, csv, csv.Rows[i], result);
                        if (err != null) { result.FailedCount++; result.ErrorDetails.Add("Dòng " + csv.Lines[i] + ": " + err); }
                    }
                });
            }
            catch (Exception ex) { return Rolled("điểm", ex); }
            Finish(result, "điểm");
            return result;
        }

        private string ImportGradeRow(SqlTx tx, Csv csv, string[] row, ImportResultModel result)
        {
            string who = csv.Get(row, "student", "studentphone", "studentemail", "phone", "email");
            string subject = csv.Get(row, "subject", "subjectname");
            string term = csv.Get(row, "term", "semester") ?? "HK1";
            string type = csv.Get(row, "type") ?? "15 phút";
            string scoreText = csv.Get(row, "score");
            string weightText = csv.Get(row, "weight");
            string dateText = csv.Get(row, "gradedate", "date");
            if (who == null || subject == null || scoreText == null) return "Thiếu học sinh, môn học hoặc điểm.";
            decimal score;
            if (!decimal.TryParse(scoreText.Replace(',', '.'), System.Globalization.NumberStyles.Number, System.Globalization.CultureInfo.InvariantCulture, out score) || score < 0 || score > 10)
                return "Điểm phải là số từ 0 đến 10.";
            int weight = DefaultWeight(type);
            if (weightText != null && (!int.TryParse(weightText, out weight) || weight < 1 || weight > 5)) return "Hệ số phải từ 1 đến 5.";
            DateTime? date = null;
            if (dateText != null)
            {
                DateTime d;
                if (!DateTime.TryParseExact(dateText, new[] { "yyyy-MM-dd", "dd/MM/yyyy" }, System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out d))
                    return "Ngày không hợp lệ (dùng yyyy-MM-dd hoặc dd/MM/yyyy).";
                date = d.Date;
            }
            if (subject.Length > 100 || term.Length > 20 || type.Length > 20) return "Môn học/học kỳ/loại điểm quá dài.";
            int? sid = tx.Query("SELECT id FROM dbo.Users WHERE role = 'HS' AND (phone = @p OR email = @e)", IdMap,
                SqlDb.P("@p", StudentService.NormalizePhone(who)), SqlDb.P("@e", who.ToLowerInvariant())).Cast<int?>().FirstOrDefault();
            if (!sid.HasValue) return "Không tìm thấy học sinh (HS) '" + who + "'.";

            int? existing = tx.Query(
                "SELECT id FROM dbo.Grade WHERE studentId = @s AND subject = @sub AND term = @t AND type = @ty AND ((gradeDate IS NULL AND @d IS NULL) OR gradeDate = @d)", IdMap,
                SqlDb.P("@s", sid.Value), SqlDb.P("@sub", subject), SqlDb.P("@t", term), SqlDb.P("@ty", type), SqlDb.P("@d", date.HasValue ? (object)date.Value : null)).Cast<int?>().FirstOrDefault();
            string label = who + " - " + subject + " " + term + " " + type + " = " + score.ToString(System.Globalization.CultureInfo.InvariantCulture);
            if (existing.HasValue)
            {
                tx.Execute("UPDATE dbo.Grade SET score = @sc, weight = @w WHERE id = @id", SqlDb.P("@sc", score), SqlDb.P("@w", (byte)weight), SqlDb.P("@id", existing.Value));
                result.UpdatedCount++; result.ImportedItems.Add("Cập nhật: " + label);
            }
            else
            {
                tx.Execute("INSERT dbo.Grade (studentId, subject, score, term, type, weight, gradeDate) VALUES (@s, @sub, @sc, @t, @ty, @w, @d)",
                    SqlDb.P("@s", sid.Value), SqlDb.P("@sub", subject), SqlDb.P("@sc", score), SqlDb.P("@t", term), SqlDb.P("@ty", type),
                    SqlDb.P("@w", (byte)weight), SqlDb.P("@d", date.HasValue ? (object)date.Value : null));
                result.InsertedCount++; result.ImportedItems.Add("Thêm mới: " + label);
            }
            return null;
        }

        // ------------------------------------------------------------------ demo rows (same as backend/sql/seed.sql, first blocks)

        /// <summary>Manager only. Applies only the missing demo rows of backend/sql/seed.sql that belong to users/classes/timetable:
        /// class 10A1 for the two demo students, parent links when none exist, the 29-lesson 10A1 timetable when the timetable is empty.</summary>
        public ImportResultModel SeedDemoData(UserModel actor)
        {
            if (actor == null || !actor.IsManager) return Fail("Từ chối quyền: chỉ Quản lý mới được khởi tạo dữ liệu mẫu.");
            var result = new ImportResultModel();
            try
            {
                SqlDb.Transaction(tx =>
                {
                    int a = tx.Execute("UPDATE dbo.Users SET className = N'10A1' WHERE email IN ('hs@fschool.vn', 'hs2@fschool.vn') AND className IS NULL");
                    int b = tx.Execute(@"IF NOT EXISTS (SELECT 1 FROM dbo.ParentStudent)
                        INSERT dbo.ParentStudent (parentId, studentId)
                        SELECT p.id, s.id FROM dbo.Users p CROSS JOIN dbo.Users s
                        WHERE p.email = 'ph@fschool.vn' AND s.email IN ('hs@fschool.vn', 'hs2@fschool.vn')");
                    int c = tx.Execute(SeedScheduleSql);
                    result.InsertedCount = Math.Max(c, 0) + Math.Max(b, 0);
                    result.UpdatedCount = Math.Max(a, 0);
                    result.ImportedItems.Add("Lớp 10A1 cho học sinh mẫu: " + Math.Max(a, 0) + " tài khoản cập nhật");
                    result.ImportedItems.Add("Liên kết phụ huynh mẫu: " + Math.Max(b, 0) + " liên kết thêm mới");
                    result.ImportedItems.Add("Thời khóa biểu 10A1 mẫu: " + Math.Max(c, 0) + " tiết thêm mới (chỉ thêm khi bảng thời khóa biểu đang trống)");
                });
            }
            catch (Exception ex) { return Rolled("dữ liệu mẫu", ex); }
            result.Message = "Đã áp dụng các dòng dữ liệu mẫu còn thiếu (không ghi đè dữ liệu đang có).";
            result.TotalProcessed = result.InsertedCount + result.UpdatedCount;
            return result;
        }

        private const string SeedScheduleSql = @"
IF NOT EXISTS (SELECT 1 FROM dbo.Schedule)
BEGIN
  DECLARE @gv INT = (SELECT id FROM dbo.Users WHERE email = 'gv@fschool.vn');
  DECLARE @gv2 INT = (SELECT id FROM dbo.Users WHERE email = 'gv2@fschool.vn');
  IF @gv IS NOT NULL AND @gv2 IS NOT NULL
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
END";
    }
}
