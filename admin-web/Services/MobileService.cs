using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;
using MyfschoolWeb.DataAccess;
using Newtonsoft.Json.Linq;

namespace MyfschoolWeb.Services
{
    /// <summary>An error that becomes {"message": ...} with the given HTTP status.</summary>
    public class MobileHttpException : Exception
    {
        public int Status { get; private set; }
        public MobileHttpException(int status, string message) : base(message) { Status = status; }
    }

    public class MobileUser
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Email { get; set; }
        public string Phone { get; set; }
        public string Role { get; set; }
        public string ClassName { get; set; }
        public string PasswordHash { get; set; }
    }

    public class MobileStudent
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string ClassName { get; set; }
    }

    /// <summary>
    /// Data access and rules of the mobile JSON API (/api/m/*). A line-by-line port of backend\dao and backend\controllers
    /// (same SQL, same access rules, same numbers/dates) so that the Flutter app only has to change its base URL.
    /// Every statement is parameterized (SqlDb.P). passwordHash never leaves this class except to the login/reset code.
    /// </summary>
    public class MobileService
    {
        public const int MaxIdentifier = 150;
        public const int MaxLoginPassword = 256;
        public const int MaxNewPassword = 72;   // bcrypt limit
        public const int MaxText = 500;
        public const string DefaultTerm = "HK1";
        public const string DefaultClass = "10A1";
        public static readonly string[] Statuses = { "pending", "approved", "rejected" };

        // Valid bcrypt hash used to equalize timing when the user does not exist.
        private static readonly string DummyHash = BCrypt.Net.BCrypt.HashPassword("dummy-password-for-timing", 10);

        // ------------------------------------------------------------ helpers

        public static string NormalizeIdentifier(string raw)
        {
            string s = raw.Trim();
            return s.Contains("@") ? s.ToLowerInvariant() : s;
        }

        public static int ParseId(string raw, string name)
        {
            if (raw == null || !Regex.IsMatch(raw, @"^[0-9]{1,9}\z") || int.Parse(raw, CultureInfo.InvariantCulture) < 1)
                throw new MobileHttpException(400, name + " must be a positive integer");
            return int.Parse(raw, CultureInfo.InvariantCulture);
        }

        /// <summary>'YYYY-MM-DD' that is a real calendar date, else null.</summary>
        public static string ParseDate(string raw)
        {
            DateTime d;
            if (raw == null || !Regex.IsMatch(raw, @"^[0-9]{4}-[0-9]{2}-[0-9]{2}\z")) return null;
            return DateTime.TryParseExact(raw, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ? raw : null;
        }

        /// <summary>JS Math.round(n * 100) / 100.</summary>
        public static double Round2(double n) { return Math.Floor(n * 100 + 0.5) / 100; }

        /// <summary>A JSON number written the way JS does (9 not 9.0); null -> JSON null.</summary>
        public static JToken Num(double? d)
        {
            if (!d.HasValue) return JValue.CreateNull();
            double v = d.Value;
            if (v == Math.Floor(v) && Math.Abs(v) < 1e15) return new JRaw(((long)v).ToString(CultureInfo.InvariantCulture));
            return new JRaw(v.ToString("R", CultureInfo.InvariantCulture));
        }

        /// <summary>Reads a whole row into a JObject in column order (ints stay ints, float/decimal become JS-style numbers).</summary>
        private static JObject Row(IDataRecord r)
        {
            var o = new JObject();
            for (int i = 0; i < r.FieldCount; i++)
            {
                string n = r.GetName(i);
                if (r.IsDBNull(i)) { o[n] = JValue.CreateNull(); continue; }
                object v = r.GetValue(i);
                if (v is byte || v is short || v is int || v is long) o[n] = new JValue(Convert.ToInt64(v));
                else if (v is double || v is float || v is decimal) o[n] = Num(Convert.ToDouble(v));
                else o[n] = new JValue(Convert.ToString(v, CultureInfo.InvariantCulture));
            }
            return o;
        }

        private static List<JObject> Rows(string sql, params SqlParameter[] ps) { return SqlDb.Query(sql, Row, ps); }

        private static MobileUser MapUser(IDataRecord r)
        {
            return new MobileUser
            {
                Id = SqlDb.Int(r, "id"), Name = SqlDb.Str(r, "name"), Email = SqlDb.Str(r, "email"), Phone = SqlDb.Str(r, "phone"),
                Role = SqlDb.Str(r, "role"), ClassName = SqlDb.Str(r, "className"), PasswordHash = SqlDb.Str(r, "passwordHash")
            };
        }

        public static object PublicUser(MobileUser u)
        {
            return new { id = u.Id, name = u.Name, email = u.Email, phone = u.Phone, role = u.Role };
        }

        // ------------------------------------------------------------ users / auth

        private const string UserCols = "id, name, email, phone, role";

        public MobileUser FindByIdentifier(string identifier)
        {
            return SqlDb.Query("SELECT TOP 1 " + UserCols + ", NULL AS className, passwordHash FROM dbo.Users WHERE email = @id OR phone = @id",
                MapUser, SqlDb.P("@id", identifier)).FirstOrDefault();
        }

        /// <summary>Profile incl. className, without the password hash (authorization code only).</summary>
        public MobileUser FindProfile(int id)
        {
            return SqlDb.Query("SELECT " + UserCols + ", className, NULL AS passwordHash FROM dbo.Users WHERE id = @id",
                MapUser, SqlDb.P("@id", id)).FirstOrDefault();
        }

        /// <summary>Verifies phone/email + password (any role). Returns null for unknown user AND wrong password (same work, same error).</summary>
        public MobileUser Authenticate(string id, string password)
        {
            if (id.Length > MaxIdentifier || password.Length > MaxLoginPassword)
            {
                SafeVerify(password.Length > 72 ? password.Substring(0, 72) : password, DummyHash);
                return null;
            }
            MobileUser user = FindByIdentifier(id);
            bool ok = SafeVerify(password, user != null ? user.PasswordHash : DummyHash);
            if (user == null || !ok) return null;
            user.PasswordHash = null;
            return user;
        }

        private static bool SafeVerify(string password, string hash)
        {
            try { return !string.IsNullOrEmpty(hash) && BCrypt.Net.BCrypt.Verify(password, hash); }
            catch (Exception) { return false; }   // malformed hash
        }

        /// <summary>Sets a new password for the user found by phone/email. Null when unknown.</summary>
        public bool ResetPassword(string id, string newPassword)
        {
            MobileUser user = id.Length > MaxIdentifier ? null : FindByIdentifier(id);
            if (user == null) return false;
            string hash = BCrypt.Net.BCrypt.HashPassword(newPassword, 10);
            SqlDb.Execute("UPDATE dbo.Users SET passwordHash = @hash WHERE id = @id", SqlDb.P("@hash", hash), SqlDb.P("@id", user.Id));
            return true;
        }

        // ------------------------------------------------------------ access (AccessDao)

        /// <summary>SQL condition on a Users row (alias) saying "this student is visible to @uid".</summary>
        public static string StudentScope(string role, string alias)
        {
            switch (role)
            {
                case "HS": return alias + ".id = @uid";
                case "PH": return alias + ".id IN (SELECT studentId FROM dbo.ParentStudent WHERE parentId = @uid)";
                case "GV": return alias + ".role = 'HS' AND " + alias + ".className IN (SELECT className FROM dbo.Schedule WHERE teacherId = @uid)";
                case "Manager": return alias + ".role = 'HS'";
                default: return "1 = 0";
            }
        }

        public List<MobileStudent> VisibleStudents(MobileUser user)
        {
            return SqlDb.Query("SELECT s.id, s.name, s.className FROM dbo.Users s WHERE " + StudentScope(user.Role, "s") + " ORDER BY s.name",
                r => new MobileStudent { Id = SqlDb.Int(r, "id"), Name = SqlDb.Str(r, "name"), ClassName = SqlDb.Str(r, "className") },
                SqlDb.P("@uid", user.Id));
        }

        /// <summary>Student a request is about: ?studentId= when given, otherwise the user's own / first child.</summary>
        public MobileStudent ResolveStudent(MobileUser user, string rawStudentId)
        {
            List<MobileStudent> students = VisibleStudents(user);
            if (rawStudentId != null)
            {
                int id = ParseId(rawStudentId, "studentId");
                MobileStudent s = students.FirstOrDefault(x => x.Id == id);
                if (s == null) throw new MobileHttpException(403, "You cannot view this student");
                return s;
            }
            if (user.Role == "HS" || user.Role == "PH")
            {
                if (students.Count == 0) throw new MobileHttpException(404, "No student linked to this account");
                return students[0];
            }
            throw new MobileHttpException(400, "studentId is required");
        }

        public static object StudentJson(MobileStudent s) { return new { id = s.Id, name = s.Name, className = s.ClassName }; }

        // ------------------------------------------------------------ schedule

        private const string SchedCols =
            @"sc.id, sc.dayOfWeek, sc.period, sc.subject, sc.className, sc.room, sc.mode, sc.content, sc.prep, sc.note,
              CONVERT(varchar(5), sc.startTime, 108) AS startTime, CONVERT(varchar(5), sc.endTime, 108) AS endTime,
              t.name AS teacherName";
        private const string SchedFrom = "FROM dbo.Schedule sc JOIN dbo.Users t ON t.id = sc.teacherId";

        public List<JObject> ScheduleByClass(string className)
        {
            return Rows("SELECT " + SchedCols + " " + SchedFrom + " WHERE sc.className = @c ORDER BY sc.dayOfWeek, sc.period", SqlDb.P("@c", className));
        }

        public List<JObject> ScheduleByTeacher(int teacherId)
        {
            return Rows("SELECT " + SchedCols + " " + SchedFrom + " WHERE sc.teacherId = @t ORDER BY sc.dayOfWeek, sc.period", SqlDb.P("@t", teacherId));
        }

        /// <summary>HS/PH: the student's class. GV: the lessons they teach. Manager: className (default 10A1).</summary>
        public object ScheduleList(MobileUser user, string rawStudentId, string classNameParam)
        {
            List<JObject> items;
            string className = null;
            if (user.Role == "GV") items = ScheduleByTeacher(user.Id);
            else if (user.Role == "Manager")
            {
                className = !string.IsNullOrEmpty(classNameParam) ? classNameParam : DefaultClass;
                items = ScheduleByClass(className);
            }
            else
            {
                MobileStudent s = ResolveStudent(user, rawStudentId);
                className = s.ClassName;
                items = ScheduleByClass(className);
            }
            return new { className = className, items = items };
        }

        public JObject ScheduleDetail(MobileUser user, int id, string rawStudentId)
        {
            JObject item = Rows("SELECT " + SchedCols + " " + SchedFrom + " WHERE sc.id = @id", SqlDb.P("@id", id)).FirstOrDefault();
            if (item == null) throw new MobileHttpException(404, "Lesson not found");
            if (user.Role == "GV")
            {
                if (!ScheduleByTeacher(user.Id).Any(x => (long)x["id"] == id)) throw new MobileHttpException(404, "Lesson not found");
            }
            else if (user.Role == "HS" || user.Role == "PH")
            {
                MobileStudent s = ResolveStudent(user, rawStudentId);
                if (!string.Equals(s.ClassName, (string)item["className"], StringComparison.Ordinal)) throw new MobileHttpException(404, "Lesson not found");
            }
            return item;
        }

        // ------------------------------------------------------------ grades

        private class GradeRow { public string Subject, Type, Date; public int Weight; public double Score; }

        private static List<GradeRow> GradesByStudentTerm(int studentId, string term)
        {
            return SqlDb.Query(
                @"SELECT subject, type, weight, CAST(score AS float) AS score, CONVERT(varchar(10), gradeDate, 23) AS date
                  FROM dbo.Grade WHERE studentId = @s AND term = @t ORDER BY subject, gradeDate, id",
                r => new GradeRow
                {
                    Subject = SqlDb.Str(r, "subject"), Type = SqlDb.Str(r, "type"), Weight = SqlDb.Int(r, "weight"),
                    Score = Convert.ToDouble(r.GetValue(r.GetOrdinal("score"))), Date = SqlDb.Str(r, "date")
                },
                SqlDb.P("@s", studentId), SqlDb.P("@t", term));
        }

        private static double? Weighted(List<GradeRow> rows)
        {
            int w = rows.Sum(r => r.Weight);
            if (w == 0) return null;
            double sum = 0;
            foreach (var r in rows) sum += r.Score * r.Weight;
            return Round2(sum / w);
        }

        private static string RankOf(double? avg)
        {
            if (avg == null) return null;
            if (avg >= 8) return "Giỏi";
            if (avg >= 6.5) return "Khá";
            if (avg >= 5) return "Trung bình";
            return "Yếu";
        }

        private static double? Mean(List<GradeRow> rows, string type)
        {
            var r = rows.Where(x => x.Type == type).ToList();
            if (r.Count == 0) return null;
            double sum = 0;
            foreach (var x in r) sum += x.Score;
            return Round2(sum / r.Count);
        }

        public static string TermOf(string raw)
        {
            return raw != null && Regex.IsMatch(raw, @"^[A-Za-z0-9]{1,20}\z") ? raw : DefaultTerm;
        }

        public object GradeSummary(MobileUser user, string rawStudentId, string rawTerm)
        {
            MobileStudent student = ResolveStudent(user, rawStudentId);
            string term = TermOf(rawTerm);
            List<GradeRow> rows = GradesByStudentTerm(student.Id, term);
            var order = new List<string>();
            var by = new Dictionary<string, List<GradeRow>>();
            foreach (var r in rows)
            {
                if (!by.ContainsKey(r.Subject)) { by[r.Subject] = new List<GradeRow>(); order.Add(r.Subject); }
                by[r.Subject].Add(r);
            }
            var subjects = new List<JObject>();
            var avgs = new List<double>();
            foreach (string subject in order)
            {
                List<GradeRow> items = by[subject];
                double? avg = Weighted(items);
                if (avg.HasValue) avgs.Add(avg.Value);
                var o = new JObject();
                o["subject"] = subject;
                o["midterm"] = Num(Mean(items, "Giữa kỳ"));
                o["final"] = Num(Mean(items, "Cuối kỳ"));
                o["average"] = Num(avg);
                subjects.Add(o);
            }
            double? average = null;
            if (avgs.Count > 0) { double s = 0; foreach (double a in avgs) s += a; average = Round2(s / avgs.Count); }
            string conduct = SqlDb.Query("SELECT conduct FROM dbo.TermSummary WHERE studentId = @s AND term = @t",
                r => SqlDb.Str(r, "conduct"), SqlDb.P("@s", student.Id), SqlDb.P("@t", term)).FirstOrDefault();
            return new
            {
                student = StudentJson(student), term = term, average = Num(average), rank = RankOf(average), conduct = conduct, subjects = subjects
            };
        }

        public object GradeDetail(MobileUser user, string rawStudentId, string rawTerm, string subject)
        {
            MobileStudent student = ResolveStudent(user, rawStudentId);
            string term = TermOf(rawTerm);
            List<GradeRow> items = GradesByStudentTerm(student.Id, term).Where(r => r.Subject == subject).ToList();
            if (items.Count == 0) throw new MobileHttpException(404, "No grades for this subject");
            var remark = SqlDb.Query(
                @"SELECT r.comment, u.name AS teacherName FROM dbo.GradeRemark r JOIN dbo.Users u ON u.id = r.teacherId
                  WHERE r.studentId = @s AND r.subject = @sub AND r.term = @t",
                r => new KeyValuePair<string, string>(SqlDb.Str(r, "teacherName"), SqlDb.Str(r, "comment")),
                SqlDb.P("@s", student.Id), SqlDb.P("@sub", subject), SqlDb.P("@t", term));
            bool has = remark.Count > 0;
            return new
            {
                student = StudentJson(student), term = term, subject = subject, average = Num(Weighted(items)),
                teacherName = has ? remark[0].Key : null, comment = has ? remark[0].Value : null,
                items = items.Select(r => new { type = r.Type, weight = r.Weight, score = Num(r.Score), date = r.Date }).ToList()
            };
        }

        // ------------------------------------------------------------ requests

        private const string ReqSelect =
            @"SELECT r.id, r.type, r.status, r.reason, r.teacherComment,
              CONVERT(varchar(10), r.fromDate, 23) AS fromDate, CONVERT(varchar(10), r.toDate, 23) AS toDate,
              CONVERT(varchar(19), r.createdAt, 126) AS createdAt, CONVERT(varchar(19), r.handledAt, 126) AS handledAt,
              s.id AS studentId, s.name AS studentName, s.className,
              c.name AS creatorName, c.role AS creatorRole, h.name AS handledByName
              FROM dbo.Requests r
              JOIN dbo.Users s ON s.id = r.studentId
              JOIN dbo.Users c ON c.id = r.createdBy
              LEFT JOIN dbo.Users h ON h.id = r.handledBy";

        private static object Shape(JObject r)
        {
            return new
            {
                id = r["id"], type = r["type"], status = r["status"], reason = r["reason"], fromDate = r["fromDate"], toDate = r["toDate"],
                createdAt = r["createdAt"],
                student = new { id = r["studentId"], name = r["studentName"], className = r["className"] },
                creator = new { name = r["creatorName"], role = r["creatorRole"] },
                teacherComment = r["teacherComment"], handledByName = r["handledByName"], handledAt = r["handledAt"]
            };
        }

        public List<object> RequestList(MobileUser user, string status)
        {
            string where = StudentScope(user.Role, "s");
            var ps = new List<SqlParameter> { SqlDb.P("@uid", user.Id) };
            if (status != null) { where += " AND r.status = @status"; ps.Add(SqlDb.P("@status", status)); }
            return Rows(ReqSelect + " WHERE " + where + " ORDER BY r.createdAt DESC, r.id DESC", ps.ToArray()).Select(Shape).ToList();
        }

        private JObject FindVisibleRow(MobileUser user, int id)
        {
            return Rows(ReqSelect + " WHERE r.id = @id AND " + StudentScope(user.Role, "s"), SqlDb.P("@id", id), SqlDb.P("@uid", user.Id)).FirstOrDefault();
        }

        public object RequestDetail(MobileUser user, int id)
        {
            JObject r = FindVisibleRow(user, id);
            if (r == null) throw new MobileHttpException(404, "Request not found");
            return Shape(r);
        }

        public bool StudentVisible(MobileUser user, long studentId)
        {
            if (studentId > int.MaxValue) return false;
            return SqlDb.Query("SELECT s.id FROM dbo.Users s WHERE s.id = @sid AND " + StudentScope(user.Role, "s"), r => 1,
                SqlDb.P("@sid", (int)studentId), SqlDb.P("@uid", user.Id)).Count > 0;
        }

        public object CreateRequest(MobileUser user, int studentId, string type, string fromDate, string toDate, string reason)
        {
            if (!StudentVisible(user, studentId)) throw new MobileHttpException(403, "You cannot create a request for this student");
            DateTime from = DateTime.ParseExact(fromDate, "yyyy-MM-dd", CultureInfo.InvariantCulture);
            DateTime to = DateTime.ParseExact(toDate, "yyyy-MM-dd", CultureInfo.InvariantCulture);
            int id = SqlDb.Scalar<int>(
                @"INSERT dbo.Requests (studentId, createdBy, type, fromDate, toDate, reason)
                  OUTPUT INSERTED.id VALUES (@sid, @by, @type, @from, @to, @reason)",
                SqlDb.P("@sid", studentId), SqlDb.P("@by", user.Id), SqlDb.P("@type", type),
                new SqlParameter("@from", SqlDbType.Date) { Value = from }, new SqlParameter("@to", SqlDbType.Date) { Value = to },
                SqlDb.P("@reason", reason));
            return Shape(FindVisibleRow(user, id));
        }

        /// <summary>GV/Manager approve or reject a pending request they can see (atomic UPDATE ... WHERE status='pending').</summary>
        public object DecideRequest(MobileUser user, int id, string decision, string comment)
        {
            if (FindVisibleRow(user, id) == null) throw new MobileHttpException(404, "Request not found");
            int n = SqlDb.Execute(
                @"UPDATE dbo.Requests SET status = @status, teacherComment = @comment, handledBy = @by, handledAt = SYSUTCDATETIME()
                  WHERE id = @id AND status = 'pending'",
                SqlDb.P("@status", decision), SqlDb.P("@comment", comment), SqlDb.P("@by", user.Id), SqlDb.P("@id", id));
            if (n <= 0) throw new MobileHttpException(409, "Request was already handled");
            return Shape(FindVisibleRow(user, id));
        }

        // ------------------------------------------------------------ clubs

        private const string MemberCount = "c.baseMembers + (SELECT COUNT(*) FROM dbo.ClubMembers m WHERE m.clubId = c.id AND m.status = 'approved')";

        public List<JObject> ClubList(int userId, string q)
        {
            // Escape LIKE wildcards so the search text is matched literally.
            string pattern = "%" + (q ?? "").Replace("[", "[[]").Replace("%", "[%]").Replace("_", "[_]") + "%";
            return Rows(
                "SELECT c.id, c.name, c.icon, " + MemberCount + @" AS memberCount, my.status AS myStatus
                 FROM dbo.Clubs c LEFT JOIN dbo.ClubMembers my ON my.clubId = c.id AND my.userId = @uid
                 WHERE c.name LIKE @q ORDER BY c.name",
                SqlDb.P("@uid", userId), SqlDb.P("@q", pattern));
        }

        private JObject ClubFind(int userId, int id)
        {
            return Rows(
                "SELECT c.id, c.name, c.icon, c.description, c.meeting, c.location, c.advisor, c.president, " + MemberCount + @" AS memberCount, my.status AS myStatus
                 FROM dbo.Clubs c LEFT JOIN dbo.ClubMembers my ON my.clubId = c.id AND my.userId = @uid
                 WHERE c.id = @id",
                SqlDb.P("@uid", userId), SqlDb.P("@id", id)).FirstOrDefault();
        }

        public JObject ClubDetail(int userId, int id)
        {
            JObject club = ClubFind(userId, id);
            if (club == null) throw new MobileHttpException(404, "Club not found");
            List<string> members = SqlDb.Query(
                @"SELECT TOP (@n) u.name FROM dbo.ClubMembers m JOIN dbo.Users u ON u.id = m.userId
                  WHERE m.clubId = @id AND m.status = 'approved' ORDER BY m.joinedAt",
                r => SqlDb.Str(r, "name"), SqlDb.P("@id", id), SqlDb.P("@n", 3));
            club["memberPreview"] = new JArray(members);
            return club;
        }

        /// <summary>Students ask to join; the membership starts as "pending".</summary>
        public void ClubJoin(int userId, int clubId)
        {
            if (ClubFind(userId, clubId) == null) throw new MobileHttpException(404, "Club not found");
            const string conflict = "You already joined or requested this club";
            int n;
            try
            {
                n = SqlDb.Execute(
                    @"IF NOT EXISTS (SELECT 1 FROM dbo.ClubMembers WHERE clubId = @c AND userId = @u)
                        INSERT dbo.ClubMembers (clubId, userId, status) VALUES (@c, @u, 'pending')",
                    SqlDb.P("@c", clubId), SqlDb.P("@u", userId));
            }
            catch (SqlException ex)
            {
                if (ex.Number == 2627 || ex.Number == 2601) throw new MobileHttpException(409, conflict);   // concurrent duplicate insert
                throw;
            }
            if (n <= 0) throw new MobileHttpException(409, conflict);
        }
    }
}
