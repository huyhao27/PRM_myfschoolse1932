using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Text.RegularExpressions;
using MyfschoolWeb.DataAccess;
using MyfschoolWeb.Models;

namespace MyfschoolWeb.Services
{
    /// <summary>
    /// Users / authentication / class-access logic on SQL Server (dbo.Users, dbo.Schedule).
    /// Roles: Manager sees everything, GV (teacher) only the classes he/she teaches.
    /// </summary>
    public class StudentService
    {
        private const string UserCols = "id, name, email, phone, role, className, createdAt";

        private static UserModel MapUser(IDataRecord r)
        {
            return new UserModel
            {
                Id = SqlDb.Int(r, "id"),
                Name = SqlDb.Str(r, "name"),
                Email = SqlDb.Str(r, "email"),
                Phone = SqlDb.Str(r, "phone"),
                Role = SqlDb.Str(r, "role"),
                ClassName = SqlDb.Str(r, "className"),
                CreatedAt = SqlDb.Date(r, "createdAt")
            };
        }

        // Old Mongo role names still used by un-migrated pages -> SQL role values.
        private static string MapRole(string role)
        {
            if (string.IsNullOrWhiteSpace(role) || role.Trim().ToUpper() == "ALL") return null;
            switch (role.Trim().ToUpper())
            {
                case "STUDENT": case "HS": return Roles.Student;
                case "TEACHER": case "GV": return Roles.Teacher;
                case "ADMIN": case "MANAGER": return Roles.Manager;
                case "PARENT": case "PH": return Roles.Parent;
                default: return role.Trim();
            }
        }

        // ------------------------------------------------------------ authentication

        /// <summary>Login identifier = phone or email. Same normalization as the Node API: trim, lower-case when it contains '@'.</summary>
        public static string NormalizeIdentifier(string raw)
        {
            string s = (raw ?? "").Trim();
            return s.Contains("@") ? s.ToLowerInvariant() : s;
        }

        /// <summary>Full login with a Vietnamese error message. Only Manager and GV may enter the portal.</summary>
        public LoginResult TryLogin(string identifier, string password)
        {
            const string invalid = "Số điện thoại/email hoặc mật khẩu không đúng.";
            string id = NormalizeIdentifier(identifier);
            if (id.Length == 0 || string.IsNullOrEmpty(password)) return new LoginResult { Error = "Vui lòng nhập số điện thoại và mật khẩu." };
            if (id.Length > 150 || password.Length > 256) return new LoginResult { Error = invalid };

            string hash = null;
            UserModel user = null;
            var rows = SqlDb.Query("SELECT TOP 1 " + UserCols + ", passwordHash FROM dbo.Users WHERE email = @id OR phone = @id",
                r => new KeyValuePair<UserModel, string>(MapUser(r), SqlDb.Str(r, "passwordHash")), SqlDb.P("@id", id));
            if (rows.Count > 0) { user = rows[0].Key; hash = rows[0].Value; }

            bool ok = false;
            try { ok = user != null && !string.IsNullOrEmpty(hash) && BCrypt.Net.BCrypt.Verify(password, hash); }
            catch (Exception) { ok = false; }   // malformed hash
            if (!ok) return new LoginResult { Error = invalid };

            if (user.Role != Roles.Manager && user.Role != Roles.Teacher)
                return new LoginResult { PortalDenied = true, Error = "Tài khoản này không có quyền truy cập Portal quản lý (chỉ dành cho Quản lý và Giáo viên)." };

            return new LoginResult { User = user };
        }

        /// <summary>Returns the user when credentials are valid AND the role may use the portal, otherwise null.</summary>
        public UserModel Authenticate(string identifier, string password)
        {
            return TryLogin(identifier, password).User;
        }

        // ------------------------------------------------------------ lookups

        public UserModel GetUserById(int id)
        {
            var l = SqlDb.Query("SELECT " + UserCols + " FROM dbo.Users WHERE id = @id", MapUser, SqlDb.P("@id", id));
            return l.FirstOrDefault();
        }

        /// <summary>Classes a teacher teaches (distinct Schedule.className) plus his/her own Users.className if set. Sorted.</summary>
        public List<string> GetTeacherClasses(int teacherId)
        {
            return SqlDb.Query(
                @"SELECT className FROM dbo.Schedule WHERE teacherId = @t
                  UNION SELECT className FROM dbo.Users WHERE id = @t AND className IS NOT NULL
                  ORDER BY className",
                r => r.GetString(0), SqlDb.P("@t", teacherId));
        }

        /// <summary>All class names known to the school (students' classes + scheduled classes). Sorted.</summary>
        public List<string> GetAllClasses()
        {
            return SqlDb.Query(
                @"SELECT className FROM dbo.Users WHERE role = 'HS' AND className IS NOT NULL
                  UNION SELECT className FROM dbo.Schedule ORDER BY className",
                r => r.GetString(0));
        }

        /// <summary>Classes this user may work with: all for Manager, taught classes for GV, none otherwise.</summary>
        public List<string> GetAccessibleClasses(UserModel user)
        {
            if (user == null) return new List<string>();
            if (user.IsManager) return GetAllClasses();
            if (user.IsTeacher) return GetTeacherClasses(user.Id);
            return new List<string>();
        }

        public bool CanAccessClass(UserModel user, string className)
        {
            if (user == null || string.IsNullOrEmpty(className)) return false;
            if (user.IsManager) return true;
            return user.IsTeacher && GetTeacherClasses(user.Id).Contains(className, StringComparer.OrdinalIgnoreCase);
        }

        /// <summary>Students (role HS). className null/"ALL" = every class. Search matches name, email, phone, id.</summary>
        public List<UserModel> GetStudents(string className = null, string searchKeyword = null)
        {
            return GetUsers(Roles.Student, className, searchKeyword);
        }

        /// <summary>Students visible to <paramref name="actor"/> (Manager: all, GV: only his/her classes), optionally narrowed by class/search.</summary>
        public List<UserModel> GetStudentsFor(UserModel actor, string className = null, string searchKeyword = null)
        {
            if (actor == null) return new List<UserModel>();
            var list = GetStudents(className, searchKeyword);
            if (actor.IsManager) return list;
            var allowed = new HashSet<string>(GetTeacherClasses(actor.Id), StringComparer.OrdinalIgnoreCase);
            return list.Where(u => u.ClassName != null && allowed.Contains(u.ClassName)).ToList();
        }

        /// <summary>role: SQL value (GV/Manager/PH/HS) or old name (STUDENT/TEACHER/ADMIN/PARENT) or null/ALL.</summary>
        public List<UserModel> GetUsers(string role = null, string className = null, string searchKeyword = null)
        {
            var where = new List<string>();
            var ps = new List<SqlParameter>();
            string r = MapRole(role);
            if (r != null) { where.Add("role = @role"); ps.Add(SqlDb.P("@role", r)); }
            if (!string.IsNullOrEmpty(className) && className != "ALL") { where.Add("className = @cls"); ps.Add(SqlDb.P("@cls", className)); }
            if (!string.IsNullOrWhiteSpace(searchKeyword))
            {
                where.Add("(name LIKE @q OR email LIKE @q OR phone LIKE @q OR CAST(id AS VARCHAR(12)) = @exact)");
                string kw = searchKeyword.Trim();
                ps.Add(SqlDb.P("@q", "%" + kw.Replace("[", "[[]").Replace("%", "[%]").Replace("_", "[_]") + "%"));
                ps.Add(SqlDb.P("@exact", kw));
            }
            string sql = "SELECT " + UserCols + " FROM dbo.Users" + (where.Count > 0 ? " WHERE " + string.Join(" AND ", where) : "") +
                         " ORDER BY role, className, name";
            return SqlDb.Query(sql, MapUser, ps.ToArray());
        }

        public UserModel GetStudentById(string studentId)
        {
            int id;
            if (!int.TryParse(studentId, out id)) return null;
            var u = GetUserById(id);
            return (u != null && u.Role == Roles.Student) ? u : null;
        }

        public UserModel GetStudentById(int id)
        {
            var u = GetUserById(id);
            return (u != null && u.Role == Roles.Student) ? u : null;
        }

        public List<string> GetDistinctStudentClasses()
        {
            return SqlDb.Query("SELECT DISTINCT className FROM dbo.Users WHERE role = 'HS' AND className IS NOT NULL ORDER BY className", r => r.GetString(0));
        }

        // ------------------------------------------------------------ writes

        /// <summary>Create a user (Manager only). Default password 123456 when none given. Returns a result object, never throws for validation problems.</summary>
        public UserCreationResult CreateUser(UserModel user, string actorRole, string plainPassword = null)
        {
            if (actorRole != Roles.Manager && actorRole != "ADMIN")
                return new UserCreationResult { Message = "Từ chối quyền: chỉ Quản lý mới được tạo tài khoản." };
            if (user == null || string.IsNullOrWhiteSpace(user.Name))
                return new UserCreationResult { Message = "Vui lòng nhập họ và tên." };

            string role = MapRole(user.Role) ?? Roles.Student;
            string phone = string.IsNullOrWhiteSpace(user.Phone) ? null : user.Phone.Trim().Replace(" ", "").Replace(".", "").Replace("-", "");
            string email = string.IsNullOrWhiteSpace(user.Email) ? null : user.Email.Trim().ToLowerInvariant();
            if (phone == null && email == null)
                return new UserCreationResult { Message = "Cần ít nhất số điện thoại hoặc email." };
            string bad = ValidateFields(user.Name, phone, email, user.ClassName);
            if (bad != null) return new UserCreationResult { Message = bad };
            if (plainPassword != null && plainPassword.Length > 0 && plainPassword.Length < 6)
                return new UserCreationResult { Message = "Mật khẩu phải có ít nhất 6 ký tự." };

            if (phone != null && SqlDb.Scalar<int>("SELECT COUNT(*) FROM dbo.Users WHERE phone = @p", SqlDb.P("@p", phone)) > 0)
                return new UserCreationResult { Message = "Số điện thoại '" + phone + "' đã được đăng ký." };
            if (email != null && SqlDb.Scalar<int>("SELECT COUNT(*) FROM dbo.Users WHERE email = @e", SqlDb.P("@e", email)) > 0)
                return new UserCreationResult { Message = "Email '" + email + "' đã tồn tại." };

            string hash = BCrypt.Net.BCrypt.HashPassword(string.IsNullOrEmpty(plainPassword) ? "123456" : plainPassword, 10);
            int id;
            try
            {
                id = SqlDb.Scalar<int>(
                    @"INSERT INTO dbo.Users (name, email, phone, passwordHash, role, className)
                      OUTPUT INSERTED.id VALUES (@n, @e, @p, @h, @r, @c)",
                    SqlDb.P("@n", user.Name.Trim()), SqlDb.P("@e", email), SqlDb.P("@p", phone), SqlDb.P("@h", hash),
                    SqlDb.P("@r", role), SqlDb.P("@c", string.IsNullOrWhiteSpace(user.ClassName) ? null : user.ClassName.Trim()));
            }
            catch (SqlException ex)
            {
                if (IsDuplicate(ex)) return new UserCreationResult { Message = "Số điện thoại hoặc email đã được dùng bởi tài khoản khác." };
                throw;
            }
            return new UserCreationResult { Success = true, User = GetUserById(id), Message = "Đã tạo tài khoản " + user.Name.Trim() + " (" + role + ")." };
        }

        /// <summary>Update name/email/phone/className of an existing user (no password change).</summary>
        public void UpdateUser(UserModel u)
        {
            if (u == null) throw new ArgumentNullException("u");
            SqlDb.Execute("UPDATE dbo.Users SET name = @n, email = @e, phone = @p, className = @c WHERE id = @id",
                SqlDb.P("@n", u.Name), SqlDb.P("@e", string.IsNullOrWhiteSpace(u.Email) ? null : u.Email.Trim().ToLowerInvariant()),
                SqlDb.P("@p", string.IsNullOrWhiteSpace(u.Phone) ? null : u.Phone.Trim()), SqlDb.P("@c", u.ClassName), SqlDb.P("@id", u.Id));
        }

        public void SetPassword(int userId, string newPassword)
        {
            SqlDb.Execute("UPDATE dbo.Users SET passwordHash = @h WHERE id = @id",
                SqlDb.P("@h", BCrypt.Net.BCrypt.HashPassword(newPassword, 10)), SqlDb.P("@id", userId));
        }

        // ------------------------------------------------------------ validation helpers (Manager tools)

        private static readonly Regex PhoneRx = new Regex(@"^\+?\d{9,11}$", RegexOptions.Compiled);
        private static readonly Regex EmailRx = new Regex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$", RegexOptions.Compiled);

        public static string NormalizePhone(string raw)
        {
            if (string.IsNullOrWhiteSpace(raw)) return null;
            return raw.Trim().Replace(" ", "").Replace(".", "").Replace("-", "");
        }

        public static bool IsValidPhone(string phone) { return phone != null && PhoneRx.IsMatch(phone); }

        public static bool IsDuplicate(SqlException ex) { return ex.Number == 2601 || ex.Number == 2627; }

        /// <summary>Vietnamese message for the first invalid field, or null when everything is fine. phone/email may be null.</summary>
        public static string ValidateFields(string name, string phone, string email, string className)
        {
            if (string.IsNullOrWhiteSpace(name)) return "Vui lòng nhập họ và tên.";
            if (name.Trim().Length > 100) return "Họ tên tối đa 100 ký tự.";
            if (phone != null && !IsValidPhone(phone)) return "Số điện thoại không hợp lệ (9-11 chữ số, có thể bắt đầu bằng +).";
            if (email != null && (email.Length > 150 || !EmailRx.IsMatch(email))) return "Email không hợp lệ.";
            if (!string.IsNullOrWhiteSpace(className) && className.Trim().Length > 20) return "Tên lớp tối đa 20 ký tự.";
            return null;
        }

        private static UserCreationResult Deny() { return new UserCreationResult { Message = "Từ chối quyền: chỉ Quản lý mới được thực hiện thao tác này." }; }

        /// <summary>Manager only. Edits name/email/phone/className with validation and friendly duplicate messages.</summary>
        public UserCreationResult UpdateUserChecked(UserModel actor, UserModel u)
        {
            if (actor == null || !actor.IsManager) return Deny();
            if (u == null || GetUserById(u.Id) == null) return new UserCreationResult { Message = "Không tìm thấy tài khoản." };
            string phone = NormalizePhone(u.Phone);
            string email = string.IsNullOrWhiteSpace(u.Email) ? null : u.Email.Trim().ToLowerInvariant();
            if (phone == null && email == null) return new UserCreationResult { Message = "Cần ít nhất số điện thoại hoặc email." };
            string bad = ValidateFields(u.Name, phone, email, u.ClassName);
            if (bad != null) return new UserCreationResult { Message = bad };
            if (phone != null && SqlDb.Scalar<int>("SELECT COUNT(*) FROM dbo.Users WHERE phone = @p AND id <> @id", SqlDb.P("@p", phone), SqlDb.P("@id", u.Id)) > 0)
                return new UserCreationResult { Message = "Số điện thoại '" + phone + "' đã được dùng bởi tài khoản khác." };
            if (email != null && SqlDb.Scalar<int>("SELECT COUNT(*) FROM dbo.Users WHERE email = @e AND id <> @id", SqlDb.P("@e", email), SqlDb.P("@id", u.Id)) > 0)
                return new UserCreationResult { Message = "Email '" + email + "' đã được dùng bởi tài khoản khác." };
            try
            {
                SqlDb.Execute("UPDATE dbo.Users SET name = @n, email = @e, phone = @p, className = @c WHERE id = @id",
                    SqlDb.P("@n", u.Name.Trim()), SqlDb.P("@e", email), SqlDb.P("@p", phone),
                    SqlDb.P("@c", string.IsNullOrWhiteSpace(u.ClassName) ? null : u.ClassName.Trim()), SqlDb.P("@id", u.Id));
            }
            catch (SqlException ex)
            {
                if (IsDuplicate(ex)) return new UserCreationResult { Message = "Số điện thoại hoặc email đã được dùng bởi tài khoản khác." };
                throw;
            }
            return new UserCreationResult { Success = true, User = GetUserById(u.Id), Message = "Đã cập nhật tài khoản " + u.Name.Trim() + "." };
        }

        /// <summary>Manager only. Bcrypt (work factor 10) like the Node API; minimum 6 characters.</summary>
        public UserCreationResult ResetPassword(UserModel actor, int userId, string newPassword)
        {
            if (actor == null || !actor.IsManager) return Deny();
            if (string.IsNullOrEmpty(newPassword) || newPassword.Length < 6) return new UserCreationResult { Message = "Mật khẩu phải có ít nhất 6 ký tự." };
            if (newPassword.Length > 72) return new UserCreationResult { Message = "Mật khẩu tối đa 72 ký tự." };
            var u = GetUserById(userId);
            if (u == null) return new UserCreationResult { Message = "Không tìm thấy tài khoản." };
            SetPassword(userId, newPassword);
            return new UserCreationResult { Success = true, User = u, Message = "Đã đặt lại mật khẩu cho " + u.Name + "." };
        }

        /// <summary>What still references the user (empty = safe to delete). Used for the friendly refusal message.</summary>
        public List<string> GetUserReferences(int userId)
        {
            var refs = new List<string>();
            Action<string, string> chk = (label, sql) =>
            {
                int n = SqlDb.Scalar<int>(sql, SqlDb.P("@id", userId));
                if (n > 0) refs.Add(n + " " + label);
            };
            chk("điểm số", "SELECT COUNT(*) FROM dbo.Grade WHERE studentId = @id");
            chk("nhận xét điểm", "SELECT COUNT(*) FROM dbo.GradeRemark WHERE studentId = @id OR teacherId = @id");
            chk("tổng kết học kỳ", "SELECT COUNT(*) FROM dbo.TermSummary WHERE studentId = @id");
            chk("đơn từ", "SELECT COUNT(*) FROM dbo.Requests WHERE studentId = @id OR createdBy = @id OR handledBy = @id");
            chk("lượt tham gia câu lạc bộ", "SELECT COUNT(*) FROM dbo.ClubMembers WHERE userId = @id");
            chk("tiết học đang dạy", "SELECT COUNT(*) FROM dbo.Schedule WHERE teacherId = @id");
            return refs;
        }

        /// <summary>Manager only. Refuses (with a message) when the user has grades/requests/memberships/lessons or is the actor. Parent links go with the user.</summary>
        public UserCreationResult DeleteUserSafe(UserModel actor, int userId)
        {
            if (actor == null || !actor.IsManager) return Deny();
            var u = GetUserById(userId);
            if (u == null) return new UserCreationResult { Message = "Không tìm thấy tài khoản." };
            if (u.Id == actor.Id) return new UserCreationResult { Message = "Không thể tự xóa tài khoản đang đăng nhập." };
            var refs = GetUserReferences(userId);
            if (refs.Count > 0)
                return new UserCreationResult { Message = "Không thể xóa " + u.Name + " vì còn dữ liệu liên quan: " + string.Join(", ", refs) + "." };
            try
            {
                SqlDb.Transaction(tx =>
                {
                    tx.Execute("DELETE FROM dbo.ParentStudent WHERE parentId = @id OR studentId = @id", SqlDb.P("@id", userId));
                    tx.Execute("DELETE FROM dbo.Users WHERE id = @id", SqlDb.P("@id", userId));
                });
            }
            catch (SqlException)
            {
                return new UserCreationResult { Message = "Không thể xóa " + u.Name + " vì còn dữ liệu liên quan." };
            }
            return new UserCreationResult { Success = true, Message = "Đã xóa tài khoản " + u.Name + "." };
        }

        // ------------------------------------------------------------ parent <-> student links

        private const string UserColsU = "u.id, u.name, u.email, u.phone, u.role, u.className, u.createdAt";

        public List<UserModel> GetParentsOf(int studentId)
        {
            return SqlDb.Query("SELECT " + UserColsU + " FROM dbo.Users u JOIN dbo.ParentStudent ps ON ps.parentId = u.id WHERE ps.studentId = @s ORDER BY u.name",
                MapUser, SqlDb.P("@s", studentId));
        }

        public List<UserModel> GetChildrenOf(int parentId)
        {
            return SqlDb.Query("SELECT " + UserColsU + " FROM dbo.Users u JOIN dbo.ParentStudent ps ON ps.studentId = u.id WHERE ps.parentId = @p ORDER BY u.className, u.name",
                MapUser, SqlDb.P("@p", parentId));
        }

        /// <summary>studentId -> "Name (phone), Name2 (phone2)" for a set of students (one query).</summary>
        public Dictionary<int, string> GetParentSummaries(IEnumerable<int> studentIds)
        {
            var result = new Dictionary<int, string>();
            var ids = studentIds.Distinct().ToList();
            if (ids.Count == 0) return result;
            var rows = SqlDb.Query(
                "SELECT ps.studentId, u.name, u.phone FROM dbo.ParentStudent ps JOIN dbo.Users u ON u.id = ps.parentId WHERE ps.studentId IN (" +
                string.Join(",", ids.Select(i => i.ToString())) + ") ORDER BY u.name",
                r => new KeyValuePair<int, string>(SqlDb.Int(r, "studentId"), SqlDb.Str(r, "name") + (string.IsNullOrEmpty(SqlDb.Str(r, "phone")) ? "" : " (" + SqlDb.Str(r, "phone") + ")")));
            foreach (var g in rows.GroupBy(x => x.Key)) result[g.Key] = string.Join(", ", g.Select(x => x.Value));
            return result;
        }

        /// <summary>Find a user (any role) by phone or email, null when none.</summary>
        public UserModel FindByIdentifier(string raw)
        {
            string s = NormalizeIdentifier(raw);
            if (s.Length == 0) return null;
            string phone = NormalizePhone(s);
            return SqlDb.Query("SELECT TOP 1 " + UserCols + " FROM dbo.Users WHERE email = @s OR phone = @p", MapUser, SqlDb.P("@s", s), SqlDb.P("@p", phone)).FirstOrDefault();
        }

        /// <summary>Manager only. Links a PH account to an HS account (idempotent).</summary>
        public UserCreationResult LinkParent(UserModel actor, int parentId, int studentId)
        {
            if (actor == null || !actor.IsManager) return Deny();
            var p = GetUserById(parentId); var s = GetUserById(studentId);
            if (p == null || p.Role != Roles.Parent) return new UserCreationResult { Message = "Tài khoản phụ huynh không hợp lệ (vai trò phải là PH)." };
            if (s == null || s.Role != Roles.Student) return new UserCreationResult { Message = "Tài khoản học sinh không hợp lệ (vai trò phải là HS)." };
            int n = SqlDb.Execute("IF NOT EXISTS (SELECT 1 FROM dbo.ParentStudent WHERE parentId = @p AND studentId = @s) INSERT dbo.ParentStudent (parentId, studentId) VALUES (@p, @s)",
                SqlDb.P("@p", parentId), SqlDb.P("@s", studentId));
            return new UserCreationResult { Success = true, Message = n > 0 ? "Đã liên kết phụ huynh " + p.Name + " với học sinh " + s.Name + "." : "Liên kết này đã tồn tại." };
        }

        public UserCreationResult UnlinkParent(UserModel actor, int parentId, int studentId)
        {
            if (actor == null || !actor.IsManager) return Deny();
            int n = SqlDb.Execute("DELETE FROM dbo.ParentStudent WHERE parentId = @p AND studentId = @s", SqlDb.P("@p", parentId), SqlDb.P("@s", studentId));
            return new UserCreationResult { Success = n > 0, Message = n > 0 ? "Đã gỡ liên kết." : "Không có liên kết để gỡ." };
        }

        // Legacy name kept for un-migrated callers.
        public void SaveStudent(UserModel student)
        {
            if (student == null) throw new ArgumentNullException("student");
            if (student.Id > 0) UpdateUser(student);
            else CreateUser(new UserModel { Name = student.Name, Email = student.Email, Phone = student.Phone, ClassName = student.ClassName, Role = Roles.Student }, Roles.Manager);
        }
    }
}
