using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using MyfschoolWeb.DataAccess;
using MyfschoolWeb.Models;

namespace MyfschoolWeb.Services
{
    public class RequestRow
    {
        public int Id { get; set; }
        public string Type { get; set; }
        public string Status { get; set; }
        public string Reason { get; set; }
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
        public DateTime CreatedAt { get; set; }
        public int StudentId { get; set; }
        public string StudentName { get; set; }
        public string ClassName { get; set; }
        public string CreatorName { get; set; }
        public string CreatorRole { get; set; }
        public string TeacherComment { get; set; }
        public string HandledByName { get; set; }
        public DateTime? HandledAt { get; set; }
    }

    public enum DecideResult { Done, AlreadyHandled, NotFound, Forbidden, Invalid }

    /// <summary>
    /// Requests (Don tu) on dbo.Requests. Same visibility and decision rules as backend RequestController/RequestDao:
    /// Manager sees every request of students, GV only students of classes he/she teaches (dbo.Schedule).
    /// </summary>
    public class RequestService
    {
        public const int MaxComment = 500;
        public static readonly string[] Types = { "Xin nghỉ học", "Xin phép đi trễ", "Xin đổi chỗ ngồi" };

        private const string Select =
            @"SELECT r.id, r.type, r.status, r.reason, r.teacherComment, r.fromDate, r.toDate, r.createdAt, r.handledAt,
                     s.id AS studentId, s.name AS studentName, s.className,
                     c.name AS creatorName, c.role AS creatorRole, h.name AS handledByName
              FROM dbo.Requests r
              JOIN dbo.Users s ON s.id = r.studentId
              JOIN dbo.Users c ON c.id = r.createdBy
              LEFT JOIN dbo.Users h ON h.id = r.handledBy";

        private static RequestRow Map(IDataRecord r)
        {
            return new RequestRow
            {
                Id = SqlDb.Int(r, "id"),
                Type = SqlDb.Str(r, "type"),
                Status = SqlDb.Str(r, "status"),
                Reason = SqlDb.Str(r, "reason"),
                FromDate = SqlDb.Date(r, "fromDate"),
                ToDate = SqlDb.Date(r, "toDate"),
                CreatedAt = SqlDb.Date(r, "createdAt") ?? DateTime.MinValue,
                StudentId = SqlDb.Int(r, "studentId"),
                StudentName = SqlDb.Str(r, "studentName"),
                ClassName = SqlDb.Str(r, "className"),
                CreatorName = SqlDb.Str(r, "creatorName"),
                CreatorRole = SqlDb.Str(r, "creatorRole"),
                TeacherComment = SqlDb.Str(r, "teacherComment"),
                HandledByName = SqlDb.Str(r, "handledByName"),
                HandledAt = SqlDb.Date(r, "handledAt")
            };
        }

        /// <summary>SQL condition "student alias is visible to @uid" (mirrors AccessDao.studentScope). Null when the role has no access.</summary>
        public static string StudentScope(UserModel actor, string alias)
        {
            if (actor == null) return null;
            if (actor.IsManager) return alias + ".role = 'HS'";
            if (actor.IsTeacher)
                return alias + ".role = 'HS' AND " + alias + ".className IN (SELECT className FROM dbo.Schedule WHERE teacherId = @uid)";
            return null;
        }

        public static string StatusText(string status)
        {
            switch (status)
            {
                case "pending": return "Chờ duyệt";
                case "approved": return "Đã duyệt";
                case "rejected": return "Từ chối";
                default: return status ?? "";
            }
        }

        public static string StatusBadgeClass(string status)
        {
            switch (status)
            {
                case "pending": return "badge bg-warning text-dark";
                case "approved": return "badge bg-success";
                case "rejected": return "badge bg-danger";
                default: return "badge bg-secondary";
            }
        }

        public static string RoleText(string role)
        {
            switch (role)
            {
                case "PH": return "Phụ huynh";
                case "HS": return "Học sinh";
                case "GV": return "Giáo viên";
                case "Manager": return "Quản lý";
                default: return role ?? "";
            }
        }

        /// <summary>Requests visible to actor, newest first. status/type/search are optional filters (search: student name, class or id).</summary>
        public List<RequestRow> List(UserModel actor, string status, string type, string search)
        {
            string scope = StudentScope(actor, "s");
            if (scope == null) return new List<RequestRow>();
            var where = new List<string> { scope };
            var ps = new List<SqlParameter> { SqlDb.P("@uid", actor.Id) };
            if (!string.IsNullOrEmpty(status) && status != "ALL")
            {
                where.Add("r.status = @status");
                ps.Add(SqlDb.P("@status", status));
            }
            if (!string.IsNullOrEmpty(type) && type != "ALL")
            {
                where.Add("r.type = @type");
                ps.Add(SqlDb.P("@type", type));
            }
            if (!string.IsNullOrWhiteSpace(search))
            {
                string kw = search.Trim();
                if (kw.Length > 100) kw = kw.Substring(0, 100);
                where.Add("(s.name LIKE @q OR s.className LIKE @q OR CAST(s.id AS VARCHAR(12)) = @exact)");
                ps.Add(SqlDb.P("@q", "%" + kw.Replace("[", "[[]").Replace("%", "[%]").Replace("_", "[_]") + "%"));
                ps.Add(SqlDb.P("@exact", kw));
            }
            return SqlDb.Query(Select + " WHERE " + string.Join(" AND ", where) + " ORDER BY r.createdAt DESC, r.id DESC", Map, ps.ToArray());
        }

        /// <summary>One request if it exists AND is visible to actor, else null.</summary>
        public RequestRow FindVisible(UserModel actor, int id)
        {
            string scope = StudentScope(actor, "s");
            if (scope == null || id <= 0) return null;
            return SqlDb.Query(Select + " WHERE r.id = @id AND " + scope, Map, SqlDb.P("@id", id), SqlDb.P("@uid", actor.Id)).FirstOrDefault();
        }

        public int CountPending(UserModel actor)
        {
            string scope = StudentScope(actor, "s");
            if (scope == null) return 0;
            return SqlDb.Scalar<int>(
                "SELECT COUNT(*) FROM dbo.Requests r JOIN dbo.Users s ON s.id = r.studentId WHERE r.status = 'pending' AND " + scope,
                SqlDb.P("@uid", actor.Id));
        }

        /// <summary>Approve/reject a pending request (decision = "approved" | "rejected"). One atomic UPDATE ... WHERE status='pending'.</summary>
        public DecideResult Decide(UserModel actor, int id, string decision, string comment)
        {
            if (actor == null || (!actor.IsManager && !actor.IsTeacher)) return DecideResult.Forbidden;
            if (decision != "approved" && decision != "rejected") return DecideResult.Invalid;
            comment = string.IsNullOrWhiteSpace(comment) ? null : comment.Trim();
            if (comment != null && comment.Length > MaxComment) return DecideResult.Invalid;
            if (FindVisible(actor, id) == null) return DecideResult.NotFound;
            int n = SqlDb.Execute(
                @"UPDATE dbo.Requests SET status = @status, teacherComment = @comment, handledBy = @by, handledAt = SYSUTCDATETIME()
                  WHERE id = @id AND status = 'pending'",
                SqlDb.P("@status", decision), SqlDb.P("@comment", comment), SqlDb.P("@by", actor.Id), SqlDb.P("@id", id));
            return n > 0 ? DecideResult.Done : DecideResult.AlreadyHandled;
        }
    }
}
