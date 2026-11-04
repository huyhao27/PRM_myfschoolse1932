using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using MyfschoolWeb.DataAccess;
using MyfschoolWeb.Models;

namespace MyfschoolWeb.Services
{
    /// <summary>
    /// Timetable on dbo.Schedule. Manager: all lessons, may add/edit/delete.
    /// GV: only the lessons he/she teaches (read-only).
    /// </summary>
    public class ScheduleService
    {
        public const int MaxPeriod = 8;

        // Fixed bell schedule; period -> start/end ("HH:mm").
        private static readonly string[] Starts = { null, "07:30", "08:25", "09:20", "10:15", "11:10", "13:30", "14:25", "15:20" };
        private static readonly string[] Ends = { null, "08:15", "09:10", "10:05", "11:00", "11:55", "14:15", "15:10", "16:05" };

        public static string PeriodStart(int period) { return period >= 1 && period <= MaxPeriod ? Starts[period] : null; }
        public static string PeriodEnd(int period) { return period >= 1 && period <= MaxPeriod ? Ends[period] : null; }

        public static string DayName(int d)
        {
            switch (d)
            {
                case 1: return "Thứ Hai";
                case 2: return "Thứ Ba";
                case 3: return "Thứ Tư";
                case 4: return "Thứ Năm";
                case 5: return "Thứ Sáu";
                case 6: return "Thứ Bảy";
                case 7: return "Chủ nhật";
                default: return "?";
            }
        }

        /// <summary>"T2".."T7","CN" or "1".."7" or Vietnamese names -> 1..7, 0 when unknown.</summary>
        public static int ParseDay(string raw)
        {
            if (string.IsNullOrWhiteSpace(raw)) return 0;
            string s = raw.Trim().ToUpperInvariant();
            int n;
            if (int.TryParse(s, out n)) return n >= 1 && n <= 7 ? n : 0;
            if (s == "CN" || s == "CHỦ NHẬT" || s == "CHU NHAT") return 7;
            if (s.Length == 2 && s[0] == 'T' && int.TryParse(s.Substring(1), out n)) return n >= 2 && n <= 7 ? n - 1 : 0;
            for (int d = 1; d <= 7; d++) if (DayName(d).ToUpperInvariant() == s) return d;
            return 0;
        }

        private const string Select =
            @"SELECT s.id, s.teacherId, t.name AS teacherName, s.className, s.subject, s.dayOfWeek, s.period, s.startTime, s.endTime,
                     s.room, s.mode, s.content, s.prep, s.note
              FROM dbo.Schedule s JOIN dbo.Users t ON t.id = s.teacherId";

        private static ScheduleModel Map(IDataRecord r)
        {
            return new ScheduleModel
            {
                Id = SqlDb.Int(r, "id"),
                TeacherId = SqlDb.Int(r, "teacherId"),
                TeacherName = SqlDb.Str(r, "teacherName"),
                ClassName = SqlDb.Str(r, "className"),
                Subject = SqlDb.Str(r, "subject"),
                DayOfWeek = SqlDb.Int(r, "dayOfWeek"),
                Period = SqlDb.Int(r, "period"),
                StartTime = SqlDb.TimeText(r, "startTime"),
                EndTime = SqlDb.TimeText(r, "endTime"),
                Room = SqlDb.Str(r, "room"),
                Mode = SqlDb.Str(r, "mode"),
                Content = SqlDb.Str(r, "content"),
                Prep = SqlDb.Str(r, "prep"),
                Note = SqlDb.Str(r, "note")
            };
        }

        /// <summary>Lessons visible to <paramref name="actor"/>, optionally narrowed by class and day (1..7, null = all).
        /// Manager: everything. GV: only lessons where he/she is the teacher. Others: nothing.</summary>
        public List<ScheduleModel> GetSchedulesFor(UserModel actor, string className = null, int? day = null)
        {
            if (actor == null || (!actor.IsManager && !actor.IsTeacher)) return new List<ScheduleModel>();
            var where = new List<string>();
            var ps = new List<SqlParameter>();
            if (actor.IsTeacher) { where.Add("s.teacherId = @me"); ps.Add(SqlDb.P("@me", actor.Id)); }
            if (!string.IsNullOrEmpty(className) && className != "ALL") { where.Add("s.className = @cls"); ps.Add(SqlDb.P("@cls", className)); }
            if (day.HasValue && day.Value >= 1 && day.Value <= 7) { where.Add("s.dayOfWeek = @d"); ps.Add(SqlDb.P("@d", day.Value)); }
            string sql = Select + (where.Count > 0 ? " WHERE " + string.Join(" AND ", where) : "") + " ORDER BY s.className, s.dayOfWeek, s.period";
            return SqlDb.Query(sql, Map, ps.ToArray());
        }

        public ScheduleModel GetById(int id)
        {
            return SqlDb.Query(Select + " WHERE s.id = @id", Map, SqlDb.P("@id", id)).FirstOrDefault();
        }

        /// <summary>Classes the actor may look at (Manager: all known classes; GV: classes he/she teaches). Sorted.</summary>
        public List<string> GetClassesFor(UserModel actor)
        {
            if (actor == null) return new List<string>();
            if (actor.IsManager) return new StudentService().GetAllClasses();
            if (actor.IsTeacher)
                return SqlDb.Query("SELECT DISTINCT className FROM dbo.Schedule WHERE teacherId = @t ORDER BY className", r => r.GetString(0), SqlDb.P("@t", actor.Id));
            return new List<string>();
        }

        /// <summary>GV accounts for the teacher drop-down.</summary>
        public List<UserModel> GetTeachers()
        {
            return new StudentService().GetUsers(Roles.Teacher);
        }

        /// <summary>Validates and normalizes a lesson in place (times always follow the bell schedule). Returns an error message or null.</summary>
        public string Validate(ScheduleModel m)
        {
            if (m == null) return "Dữ liệu tiết học không hợp lệ.";
            m.ClassName = (m.ClassName ?? "").Trim();
            m.Subject = (m.Subject ?? "").Trim();
            if (m.ClassName.Length == 0 || m.ClassName.Length > 20) return "Vui lòng nhập tên lớp (tối đa 20 ký tự).";
            if (m.Subject.Length == 0 || m.Subject.Length > 100) return "Vui lòng nhập môn học (tối đa 100 ký tự).";
            if (m.DayOfWeek < 1 || m.DayOfWeek > 7) return "Thứ trong tuần phải từ 1 (Thứ Hai) đến 7 (Chủ nhật).";
            if (m.Period < 1 || m.Period > MaxPeriod) return "Tiết học phải từ 1 đến " + MaxPeriod + ".";
            if (m.TeacherId <= 0 || SqlDb.Scalar<int>("SELECT COUNT(*) FROM dbo.Users WHERE id = @t AND role = 'GV'", SqlDb.P("@t", m.TeacherId)) == 0)
                return "Vui lòng chọn giáo viên (tài khoản vai trò GV).";
            if (!string.IsNullOrWhiteSpace(m.Room) && m.Room.Trim().Length > 30) return "Phòng học tối đa 30 ký tự.";
            m.StartTime = PeriodStart(m.Period);
            m.EndTime = PeriodEnd(m.Period);
            m.Room = Clip(m.Room, 30); m.Mode = Clip(m.Mode, 30); m.Content = Clip(m.Content, 200); m.Prep = Clip(m.Prep, 200); m.Note = Clip(m.Note, 300);
            return null;
        }

        private static string Clip(string s, int max)
        {
            if (string.IsNullOrWhiteSpace(s)) return null;
            s = s.Trim();
            return s.Length > max ? s.Substring(0, max) : s;
        }

        /// <summary>Does another lesson already use class+day+period? (excludeId = the lesson being edited, 0 for new).</summary>
        public bool SlotTaken(string className, int day, int period, int excludeId)
        {
            return SqlDb.Scalar<int>("SELECT COUNT(*) FROM dbo.Schedule WHERE className = @c AND dayOfWeek = @d AND period = @p AND id <> @id",
                SqlDb.P("@c", className), SqlDb.P("@d", day), SqlDb.P("@p", period), SqlDb.P("@id", excludeId)) > 0;
        }

        /// <summary>Class where the teacher already teaches in that day+period (other than className), or null.</summary>
        public string TeacherBusy(int teacherId, int day, int period, string className, int excludeId)
        {
            return SqlDb.Query("SELECT TOP 1 className FROM dbo.Schedule WHERE teacherId = @t AND dayOfWeek = @d AND period = @p AND className <> @c AND id <> @id",
                r => r.GetString(0), SqlDb.P("@t", teacherId), SqlDb.P("@d", day), SqlDb.P("@p", period), SqlDb.P("@c", className), SqlDb.P("@id", excludeId)).FirstOrDefault();
        }

        /// <summary>Manager only. Insert (Id = 0) or update. Returns null on success, else a Vietnamese error.</summary>
        public string Save(UserModel actor, ScheduleModel m)
        {
            if (actor == null || !actor.IsManager) return "Từ chối quyền: chỉ Quản lý mới được sửa thời khóa biểu.";
            string err = Validate(m);
            if (err != null) return err;
            if (m.Id > 0 && GetById(m.Id) == null) return "Không tìm thấy tiết học.";
            if (SlotTaken(m.ClassName, m.DayOfWeek, m.Period, m.Id))
                return "Lớp " + m.ClassName + " đã có tiết " + m.Period + " vào " + DayName(m.DayOfWeek) + ".";
            string busy = TeacherBusy(m.TeacherId, m.DayOfWeek, m.Period, m.ClassName, m.Id);
            if (busy != null) return "Giáo viên đã có tiết " + m.Period + " vào " + DayName(m.DayOfWeek) + " ở lớp " + busy + ".";
            try
            {
                if (m.Id <= 0)
                    m.Id = SqlDb.Scalar<int>(
                        @"INSERT INTO dbo.Schedule (teacherId, className, subject, dayOfWeek, period, startTime, endTime, room, mode, content, prep, note)
                          OUTPUT INSERTED.id VALUES (@t, @c, @s, @d, @p, @st, @et, @r, @m, @ct, @pr, @n)", Params(m, false));
                else
                    SqlDb.Execute(
                        @"UPDATE dbo.Schedule SET teacherId=@t, className=@c, subject=@s, dayOfWeek=@d, period=@p, startTime=@st, endTime=@et,
                          room=@r, mode=@m, content=@ct, prep=@pr, note=@n WHERE id=@id", Params(m, true));
            }
            catch (SqlException ex)
            {
                return "Không lưu được tiết học: " + ex.Message;
            }
            return null;
        }

        internal static SqlParameter[] Params(ScheduleModel m, bool withId)
        {
            var l = new List<SqlParameter>
            {
                SqlDb.P("@t", m.TeacherId), SqlDb.P("@c", m.ClassName), SqlDb.P("@s", m.Subject), SqlDb.P("@d", (byte)m.DayOfWeek),
                SqlDb.P("@p", (byte)m.Period), SqlDb.P("@st", TimeSpan.Parse(m.StartTime)), SqlDb.P("@et", TimeSpan.Parse(m.EndTime)),
                SqlDb.P("@r", m.Room), SqlDb.P("@m", m.Mode), SqlDb.P("@ct", m.Content), SqlDb.P("@pr", m.Prep), SqlDb.P("@n", m.Note)
            };
            if (withId) l.Add(SqlDb.P("@id", m.Id));
            return l.ToArray();
        }

        /// <summary>Manager only. Returns null on success.</summary>
        public string Delete(UserModel actor, int id)
        {
            if (actor == null || !actor.IsManager) return "Từ chối quyền: chỉ Quản lý mới được xóa tiết học.";
            return SqlDb.Execute("DELETE FROM dbo.Schedule WHERE id = @id", SqlDb.P("@id", id)) > 0 ? null : "Không tìm thấy tiết học.";
        }
    }
}
