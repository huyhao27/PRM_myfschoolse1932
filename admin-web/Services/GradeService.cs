using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using MyfschoolWeb.DataAccess;
using MyfschoolWeb.Models;

namespace MyfschoolWeb.Services
{
    /// <summary>Grades on SQL Server: dbo.Grade (one row per score), dbo.GradeRemark, dbo.TermSummary.</summary>
    public class GradeService
    {
        public static readonly string[] Types = { "Miệng", "15 phút", "1 tiết", "Giữa kỳ", "Cuối kỳ" };
        public const string DefaultTerm = "HK1";

        private readonly StudentService _students = new StudentService();

        // ------------------------------------------------------------ pure helpers

        public static int WeightOf(string type)
        {
            switch (type)
            {
                case "1 tiết":
                case "Giữa kỳ": return 2;
                case "Cuối kỳ": return 3;
                default: return 1;
            }
        }

        public static string NormalizeType(string type)
        {
            if (type == null) return null;
            return Types.FirstOrDefault(t => string.Equals(t, type.Trim(), StringComparison.OrdinalIgnoreCase));
        }

        /// <summary>Weighted mean by each row's weight, rounded to 2 decimals (identical to the API).</summary>
        public static decimal? Weighted(IEnumerable<GradeEntry> entries)
        {
            if (entries == null) return null;
            var l = entries.ToList();
            int w = l.Sum(e => e.Weight);
            if (w == 0) return null;
            return Math.Round(l.Sum(e => e.Score * e.Weight) / w, 2, MidpointRounding.AwayFromZero);
        }

        public static string Evaluate(decimal? avg)
        {
            if (!avg.HasValue) return "-";
            if (avg >= 8m) return "Tốt";
            if (avg >= 6.5m) return "Khá";
            if (avg >= 5m) return "Đạt";
            return "Chưa đạt";
        }

        public static string BadgeFor(string level)
        {
            switch (level)
            {
                case "Tốt": return "badge bg-success";
                case "Khá": return "badge bg-primary";
                case "Đạt": return "badge bg-warning text-dark";
                case "-": return "badge bg-secondary";
                default: return "badge bg-danger";
            }
        }

        public static bool IsValidTerm(string t) { return !string.IsNullOrEmpty(t) && Regex.IsMatch(t, "^[A-Za-z0-9]{1,20}$"); }

        public static string TermLabel(string t)
        {
            if (t == "HK1") return "Học kỳ 1";
            if (t == "HK2") return "Học kỳ 2";
            return t;
        }

        /// <summary>Schedule uses short subject names (Lý, Hóa, Tin...), grades use long ones (Vật lý, Hóa học, Tin học...). Map both to one name.</summary>
        public static string CanonSubject(string s)
        {
            if (s == null) return null;
            string k = s.Trim().Normalize(NormalizationForm.FormC);
            switch (k.ToLowerInvariant())
            {
                case "lý": case "vật lý": case "vật lí": return "Vật lý";
                case "hóa": case "hóa học": return "Hóa học";
                case "tin": case "tin học": return "Tin học";
                case "văn": case "ngữ văn": return "Ngữ văn";
                case "anh": case "tiếng anh": return "Tiếng Anh";
                case "sinh": case "sinh học": return "Sinh học";
                case "sử": case "lịch sử": return "Lịch sử";
                case "địa": case "địa lý": case "địa lí": return "Địa lý";
                default: return k;
            }
        }

        // ------------------------------------------------------------ permissions

        /// <summary>Subjects (canonical names) a GV teaches in a class according to dbo.Schedule.</summary>
        public HashSet<string> TaughtSubjects(int teacherId, string className)
        {
            var l = SqlDb.Query("SELECT DISTINCT subject FROM dbo.Schedule WHERE teacherId = @t AND className = @c",
                r => r.GetString(0), SqlDb.P("@t", teacherId), SqlDb.P("@c", className));
            return new HashSet<string>(l.Select(CanonSubject), StringComparer.OrdinalIgnoreCase);
        }

        public bool CanView(UserModel actor, string className) { return _students.CanAccessClass(actor, className); }

        /// <summary>Manager: always. GV: only classes and subjects they teach (Schedule).</summary>
        public bool CanEdit(UserModel actor, string className, string subject)
        {
            if (actor == null) return false;
            if (actor.IsManager) return true;
            if (!actor.IsTeacher || !_students.CanAccessClass(actor, className)) return false;
            return TaughtSubjects(actor.Id, className).Contains(CanonSubject(subject));
        }

        // ------------------------------------------------------------ queries

        /// <summary>Subjects the actor may add grades for in a class (GV: subjects they teach there; Manager: every known subject).</summary>
        public List<string> GetEditableSubjects(UserModel actor, string className)
        {
            if (actor == null) return new List<string>();
            if (actor.IsTeacher)
                return CanView(actor, className) ? TaughtSubjects(actor.Id, className).OrderBy(x => x, StringComparer.CurrentCulture).ToList() : new List<string>();
            var all = SqlDb.Query("SELECT DISTINCT subject FROM dbo.Grade UNION SELECT DISTINCT subject FROM dbo.Schedule", r => r.GetString(0));
            return all.Select(CanonSubject).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(x => x, StringComparer.CurrentCulture).ToList();
        }

        /// <summary>Subjects present in Grade for the classes the actor can see (for filters).</summary>
        public List<string> GetFilterSubjects(UserModel actor)
        {
            var classes = _students.GetAccessibleClasses(actor);
            if (classes.Count == 0) return new List<string>();
            var ps = new List<SqlParameter>();
            string inSql = InList(classes, "@c", ps);
            return SqlDb.Query("SELECT DISTINCT g.subject FROM dbo.Grade g JOIN dbo.Users u ON u.id = g.studentId WHERE u.className IN (" + inSql + ") ORDER BY g.subject",
                r => r.GetString(0), ps.ToArray());
        }

        public List<string> GetTerms()
        {
            var l = SqlDb.Query("SELECT DISTINCT term FROM dbo.Grade WHERE term IS NOT NULL", r => r.GetString(0));
            foreach (var t in new[] { "HK1", "HK2" }) if (!l.Contains(t)) l.Add(t);
            l.Sort(StringComparer.OrdinalIgnoreCase);
            return l;
        }

        private static string InList(IEnumerable<string> values, string prefix, List<SqlParameter> ps)
        {
            var names = new List<string>();
            int i = 0;
            foreach (var v in values) { string n = prefix + (i++); names.Add(n); ps.Add(SqlDb.P(n, v)); }
            return string.Join(",", names);
        }

        private const string RowCols = "g.id, g.studentId, u.name AS studentName, u.className, g.subject, g.term, g.type, g.weight, g.score, g.gradeDate";

        private static GradeEntry MapEntry(IDataRecord r)
        {
            return new GradeEntry { Id = SqlDb.Int(r, "id"), Type = SqlDb.Str(r, "type"), Weight = SqlDb.Int(r, "weight", 1), Score = SqlDb.Dec(r, "score") ?? 0m, Date = SqlDb.Date(r, "gradeDate") };
        }

        private List<GradeModel> BuildModels(string sql, SqlParameter[] ps)
        {
            var models = new List<GradeModel>();
            var index = new Dictionary<string, GradeModel>(StringComparer.OrdinalIgnoreCase);
            var rows = SqlDb.Query(sql, r => new
            {
                StudentId = SqlDb.Int(r, "studentId"), StudentName = SqlDb.Str(r, "studentName"), ClassName = SqlDb.Str(r, "className"),
                Subject = SqlDb.Str(r, "subject"), Term = SqlDb.Str(r, "term"), Entry = MapEntry(r)
            }, ps);
            foreach (var row in rows)
            {
                string key = row.StudentId + "|" + row.Subject + "|" + row.Term;
                GradeModel m;
                if (!index.TryGetValue(key, out m))
                {
                    m = new GradeModel { StudentId = row.StudentId, StudentName = row.StudentName, ClassName = row.ClassName, Subject = row.Subject, Term = row.Term };
                    index[key] = m; models.Add(m);
                }
                m.Entries.Add(row.Entry);
            }
            if (models.Count > 0)
            {
                var ids = models.Select(m => m.StudentId).Distinct().ToList();
                var rps = new List<SqlParameter>();
                var names = new List<string>();
                for (int i = 0; i < ids.Count; i++) { names.Add("@s" + i); rps.Add(SqlDb.P("@s" + i, ids[i])); }
                var remarks = SqlDb.Query(
                    "SELECT r.studentId, r.subject, r.term, r.comment, r.teacherId, t.name AS teacherName FROM dbo.GradeRemark r JOIN dbo.Users t ON t.id = r.teacherId WHERE r.studentId IN (" + string.Join(",", names) + ")",
                    r => new { S = SqlDb.Int(r, "studentId"), Sub = SqlDb.Str(r, "subject"), T = SqlDb.Str(r, "term"), C = SqlDb.Str(r, "comment"), TId = SqlDb.IntN(r, "teacherId"), TN = SqlDb.Str(r, "teacherName") },
                    rps.ToArray());
                foreach (var rm in remarks)
                {
                    GradeModel m;
                    if (index.TryGetValue(rm.S + "|" + rm.Sub + "|" + rm.T, out m)) { m.Comment = rm.C; m.TeacherId = rm.TId; m.TeacherName = rm.TN; }
                }
            }
            return models;
        }

        /// <summary>Class gradebook: one GradeModel per student x subject x term, restricted to classes the actor can see.</summary>
        public List<GradeModel> GetGradebook(UserModel actor, string className = null, string subject = null, string term = null, string search = null)
        {
            var classes = _students.GetAccessibleClasses(actor);
            if (!string.IsNullOrEmpty(className) && className != "ALL")
                classes = classes.Where(c => string.Equals(c, className, StringComparison.OrdinalIgnoreCase)).ToList();
            if (classes.Count == 0) return new List<GradeModel>();

            var ps = new List<SqlParameter>();
            var where = new List<string> { "u.className IN (" + InList(classes, "@c", ps) + ")" };
            if (!string.IsNullOrEmpty(subject) && subject != "ALL") { where.Add("g.subject = @subject"); ps.Add(SqlDb.P("@subject", subject)); }
            if (!string.IsNullOrEmpty(term) && term != "ALL") { where.Add("g.term = @term"); ps.Add(SqlDb.P("@term", term)); }
            if (!string.IsNullOrWhiteSpace(search))
            {
                string kw = search.Trim();
                where.Add("(u.name LIKE @q OR CAST(u.id AS VARCHAR(12)) = @exact)");
                ps.Add(SqlDb.P("@q", "%" + kw.Replace("[", "[[]").Replace("%", "[%]").Replace("_", "[_]") + "%"));
                ps.Add(SqlDb.P("@exact", kw));
            }
            string sql = "SELECT " + RowCols + " FROM dbo.Grade g JOIN dbo.Users u ON u.id = g.studentId WHERE " + string.Join(" AND ", where) +
                         " ORDER BY u.className, u.name, g.subject, g.term, g.gradeDate, g.id";
            return BuildModels(sql, ps.ToArray());
        }

        /// <summary>One student x subject x term (no access check; call CanView afterwards). Null when no score rows exist.</summary>
        public GradeModel Get(int studentId, string subject, string term)
        {
            if (string.IsNullOrWhiteSpace(subject) || !IsValidTerm(term)) return null;
            string sql = "SELECT " + RowCols + " FROM dbo.Grade g JOIN dbo.Users u ON u.id = g.studentId WHERE g.studentId = @s AND g.subject = @sub AND g.term = @t ORDER BY g.gradeDate, g.id";
            return BuildModels(sql, new[] { SqlDb.P("@s", studentId), SqlDb.P("@sub", subject.Trim()), SqlDb.P("@t", term) }).FirstOrDefault();
        }

        public string GetConduct(int studentId, string term)
        {
            return SqlDb.Scalar<string>("SELECT conduct FROM dbo.TermSummary WHERE studentId = @s AND term = @t", SqlDb.P("@s", studentId), SqlDb.P("@t", term));
        }

        // ------------------------------------------------------------ writes

        /// <summary>
        /// Replace all score rows of student+subject+term with <paramref name="entries"/> and upsert the teacher remark (one transaction).
        /// Returns null on success or a Vietnamese error message.
        /// </summary>
        public string Save(UserModel actor, int studentId, string subject, string term, List<GradeEntry> entries, string comment)
        {
            if (actor == null) return "Bạn cần đăng nhập.";
            subject = (subject ?? "").Trim();
            if (subject.Length == 0 || subject.Length > 100) return "Tên môn học không hợp lệ.";
            if (!IsValidTerm(term)) return "Học kỳ không hợp lệ.";
            var student = _students.GetStudentById(studentId);
            if (student == null) return "Không tìm thấy học sinh.";
            if (!CanView(actor, student.ClassName)) return "Bạn không có quyền với lớp " + student.ClassName + ".";
            if (!CanEdit(actor, student.ClassName, subject)) return "Bạn chỉ được nhập/sửa điểm môn mình giảng dạy (theo thời khóa biểu).";
            if (entries == null || entries.Count == 0) return "Vui lòng nhập ít nhất một điểm.";
            if (entries.Count > 40) return "Quá nhiều đầu điểm.";
            var clean = new List<GradeEntry>();
            foreach (var e in entries)
            {
                string type = NormalizeType(e.Type);
                if (type == null) return "Loại điểm không hợp lệ: " + e.Type;
                if (e.Score < 0m || e.Score > 10m) return "Điểm phải nằm trong khoảng 0 đến 10.";
                clean.Add(new GradeEntry { Type = type, Weight = WeightOf(type), Score = Math.Round(e.Score, 2, MidpointRounding.AwayFromZero), Date = e.Date });
            }
            comment = string.IsNullOrWhiteSpace(comment) ? null : comment.Trim();
            if (comment != null && comment.Length > 300) comment = comment.Substring(0, 300);

            SqlDb.Transaction(tx =>
            {
                tx.Execute("DELETE FROM dbo.Grade WHERE studentId = @s AND subject = @sub AND term = @t",
                    SqlDb.P("@s", studentId), SqlDb.P("@sub", subject), SqlDb.P("@t", term));
                foreach (var e in clean)
                {
                    tx.Execute("INSERT dbo.Grade (studentId, subject, score, term, type, weight, gradeDate) VALUES (@s, @sub, @score, @t, @type, @w, @d)",
                        SqlDb.P("@s", studentId), SqlDb.P("@sub", subject), SqlDb.P("@score", e.Score), SqlDb.P("@t", term),
                        SqlDb.P("@type", e.Type), SqlDb.P("@w", e.Weight), SqlDb.P("@d", (e.Date ?? DateTime.Today).Date));
                }
                int? existingTeacher = tx.Query("SELECT teacherId FROM dbo.GradeRemark WHERE studentId = @s AND subject = @sub AND term = @t",
                    r => (int?)r.GetInt32(0), SqlDb.P("@s", studentId), SqlDb.P("@sub", subject), SqlDb.P("@t", term)).FirstOrDefault();
                if (existingTeacher.HasValue && comment == null)
                {
                    tx.Execute("UPDATE dbo.GradeRemark SET comment = NULL WHERE studentId = @s AND subject = @sub AND term = @t",
                        SqlDb.P("@s", studentId), SqlDb.P("@sub", subject), SqlDb.P("@t", term));
                }
                else if (comment != null)
                {
                    int teacherId = actor.IsTeacher ? actor.Id : (existingTeacher ?? FindTeacher(tx, student.ClassName, subject) ?? actor.Id);
                    tx.Execute(
                        @"MERGE dbo.GradeRemark AS t USING (SELECT @s AS studentId, @sub AS subject, @t AS term) AS x
                          ON t.studentId = x.studentId AND t.subject = x.subject AND t.term = x.term
                          WHEN MATCHED THEN UPDATE SET teacherId = @tid, comment = @c
                          WHEN NOT MATCHED THEN INSERT (studentId, subject, term, teacherId, comment) VALUES (@s, @sub, @t, @tid, @c);",
                        SqlDb.P("@s", studentId), SqlDb.P("@sub", subject), SqlDb.P("@t", term), SqlDb.P("@tid", teacherId), SqlDb.P("@c", comment));
                }
            });
            return null;
        }

        private int? FindTeacher(SqlTx tx, string className, string subject)
        {
            var rows = tx.Query("SELECT teacherId, subject FROM dbo.Schedule WHERE className = @c", r => new { T = r.GetInt32(0), S = r.GetString(1) }, SqlDb.P("@c", className));
            var hit = rows.FirstOrDefault(x => string.Equals(CanonSubject(x.S), CanonSubject(subject), StringComparison.OrdinalIgnoreCase));
            return hit == null ? (int?)null : hit.T;
        }

        /// <summary>Delete every score row (and the remark) of student+subject+term. Returns null on success or an error message.</summary>
        public string Delete(UserModel actor, int studentId, string subject, string term)
        {
            if (actor == null) return "Bạn cần đăng nhập.";
            var g = Get(studentId, subject, term);
            if (g == null) return "Không tìm thấy bảng điểm.";
            if (!CanEdit(actor, g.ClassName, g.Subject)) return "Bạn không có quyền xóa điểm môn này.";
            SqlDb.Transaction(tx =>
            {
                tx.Execute("DELETE FROM dbo.Grade WHERE studentId = @s AND subject = @sub AND term = @t",
                    SqlDb.P("@s", studentId), SqlDb.P("@sub", g.Subject), SqlDb.P("@t", term));
                tx.Execute("DELETE FROM dbo.GradeRemark WHERE studentId = @s AND subject = @sub AND term = @t",
                    SqlDb.P("@s", studentId), SqlDb.P("@sub", g.Subject), SqlDb.P("@t", term));
            });
            return null;
        }
    }
}
