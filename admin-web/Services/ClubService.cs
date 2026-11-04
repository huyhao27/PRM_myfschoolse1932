using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using MyfschoolWeb.DataAccess;
using MyfschoolWeb.Models;

namespace MyfschoolWeb.Services
{
    public class ClubRow
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Icon { get; set; }
        public string Description { get; set; }
        public string Meeting { get; set; }
        public string Location { get; set; }
        public string Advisor { get; set; }
        public string President { get; set; }
        public int BaseMembers { get; set; }
        public int ApprovedMembers { get; set; }
        public int PendingMembers { get; set; }
        public int MemberCount { get { return BaseMembers + ApprovedMembers; } }
    }

    public class ClubMemberRow
    {
        public int UserId { get; set; }
        public string Name { get; set; }
        public string ClassName { get; set; }
        public string Role { get; set; }
        public string Status { get; set; }
        public DateTime JoinedAt { get; set; }
    }

    /// <summary>Clubs on dbo.Clubs / dbo.ClubMembers. memberCount = baseMembers + approved members (same as the API).</summary>
    public class ClubService
    {
        private const string Select =
            @"SELECT c.id, c.name, c.icon, c.description, c.meeting, c.location, c.advisor, c.president, c.baseMembers,
                     (SELECT COUNT(*) FROM dbo.ClubMembers m WHERE m.clubId = c.id AND m.status = 'approved') AS approvedMembers,
                     (SELECT COUNT(*) FROM dbo.ClubMembers m WHERE m.clubId = c.id AND m.status = 'pending') AS pendingMembers
              FROM dbo.Clubs c";

        private static ClubRow Map(IDataRecord r)
        {
            return new ClubRow
            {
                Id = SqlDb.Int(r, "id"),
                Name = SqlDb.Str(r, "name"),
                Icon = SqlDb.Str(r, "icon"),
                Description = SqlDb.Str(r, "description"),
                Meeting = SqlDb.Str(r, "meeting"),
                Location = SqlDb.Str(r, "location"),
                Advisor = SqlDb.Str(r, "advisor"),
                President = SqlDb.Str(r, "president"),
                BaseMembers = SqlDb.Int(r, "baseMembers"),
                ApprovedMembers = SqlDb.Int(r, "approvedMembers"),
                PendingMembers = SqlDb.Int(r, "pendingMembers")
            };
        }

        public static bool CanManage(UserModel u) { return u != null && (u.IsManager || u.IsTeacher); }

        public List<ClubRow> List(string search)
        {
            string kw = (search ?? "").Trim();
            if (kw.Length > 50) kw = kw.Substring(0, 50);
            return SqlDb.Query(Select + " WHERE c.name LIKE @q ORDER BY c.name", Map,
                SqlDb.P("@q", "%" + kw.Replace("[", "[[]").Replace("%", "[%]").Replace("_", "[_]") + "%"));
        }

        public ClubRow Find(int id)
        {
            if (id <= 0) return null;
            return SqlDb.Query(Select + " WHERE c.id = @id", Map, SqlDb.P("@id", id)).FirstOrDefault();
        }

        public int CountPendingJoins()
        {
            return SqlDb.Scalar<int>("SELECT COUNT(*) FROM dbo.ClubMembers WHERE status = 'pending'");
        }

        /// <summary>Members (pending first, then by name).</summary>
        public List<ClubMemberRow> Members(int clubId)
        {
            return SqlDb.Query(
                @"SELECT m.userId, u.name, u.className, u.role, m.status, m.joinedAt
                  FROM dbo.ClubMembers m JOIN dbo.Users u ON u.id = m.userId
                  WHERE m.clubId = @c
                  ORDER BY CASE m.status WHEN 'pending' THEN 0 ELSE 1 END, u.name",
                r => new ClubMemberRow
                {
                    UserId = SqlDb.Int(r, "userId"),
                    Name = SqlDb.Str(r, "name"),
                    ClassName = SqlDb.Str(r, "className"),
                    Role = SqlDb.Str(r, "role"),
                    Status = SqlDb.Str(r, "status"),
                    JoinedAt = SqlDb.Date(r, "joinedAt") ?? DateTime.MinValue
                }, SqlDb.P("@c", clubId));
        }

        /// <summary>Approve a pending join request. False when it is not pending any more.</summary>
        public bool ApproveMember(UserModel actor, int clubId, int userId)
        {
            if (!CanManage(actor)) return false;
            return SqlDb.Execute("UPDATE dbo.ClubMembers SET status = 'approved' WHERE clubId = @c AND userId = @u AND status = 'pending'",
                SqlDb.P("@c", clubId), SqlDb.P("@u", userId)) > 0;
        }

        /// <summary>Reject = delete the pending row (the student may ask again). Approved rows are never touched here.</summary>
        public bool RejectMember(UserModel actor, int clubId, int userId)
        {
            if (!CanManage(actor)) return false;
            return SqlDb.Execute("DELETE FROM dbo.ClubMembers WHERE clubId = @c AND userId = @u AND status = 'pending'",
                SqlDb.P("@c", clubId), SqlDb.P("@u", userId)) > 0;
        }

        /// <summary>Validate club fields; returns a Vietnamese error or null.</summary>
        public static string Validate(ClubRow c)
        {
            if (string.IsNullOrWhiteSpace(c.Name)) return "Vui lòng nhập tên câu lạc bộ.";
            if (c.Name.Trim().Length > 100) return "Tên CLB tối đa 100 ký tự.";
            if ((c.Icon ?? "").Length > 10) return "Biểu tượng tối đa 10 ký tự.";
            if ((c.Description ?? "").Length > 500) return "Mô tả tối đa 500 ký tự.";
            if ((c.Meeting ?? "").Length > 100) return "Lịch sinh hoạt tối đa 100 ký tự.";
            if ((c.Location ?? "").Length > 100) return "Địa điểm tối đa 100 ký tự.";
            if ((c.Advisor ?? "").Length > 100) return "Giáo viên phụ trách tối đa 100 ký tự.";
            if ((c.President ?? "").Length > 100) return "Chủ nhiệm CLB tối đa 100 ký tự.";
            if (c.BaseMembers < 0 || c.BaseMembers > 100000) return "Số thành viên gốc phải từ 0 đến 100000.";
            return null;
        }

        private static object N(string s) { return string.IsNullOrWhiteSpace(s) ? null : s.Trim(); }

        /// <summary>Manager only. Returns error text or null on success.</summary>
        public string Update(UserModel actor, ClubRow c)
        {
            if (actor == null || !actor.IsManager) return "Chỉ Quản lý mới được sửa thông tin câu lạc bộ.";
            string err = Validate(c);
            if (err != null) return err;
            int n = SqlDb.Execute(
                @"UPDATE dbo.Clubs SET name = @n, icon = @i, description = @d, meeting = @m, location = @l,
                         advisor = @a, president = @p, baseMembers = @b WHERE id = @id",
                SqlDb.P("@n", c.Name.Trim()), SqlDb.P("@i", N(c.Icon)), SqlDb.P("@d", N(c.Description)), SqlDb.P("@m", N(c.Meeting)),
                SqlDb.P("@l", N(c.Location)), SqlDb.P("@a", N(c.Advisor)), SqlDb.P("@p", N(c.President)), SqlDb.P("@b", c.BaseMembers),
                SqlDb.P("@id", c.Id));
            return n > 0 ? null : "Không tìm thấy câu lạc bộ.";
        }

        /// <summary>Manager only. Returns new id (error in out parameter).</summary>
        public int Create(UserModel actor, ClubRow c, out string error)
        {
            error = null;
            if (actor == null || !actor.IsManager) { error = "Chỉ Quản lý mới được tạo câu lạc bộ."; return 0; }
            error = Validate(c);
            if (error != null) return 0;
            return SqlDb.Scalar<int>(
                @"INSERT INTO dbo.Clubs (name, icon, description, meeting, location, advisor, president, baseMembers)
                  OUTPUT INSERTED.id VALUES (@n, @i, @d, @m, @l, @a, @p, @b)",
                SqlDb.P("@n", c.Name.Trim()), SqlDb.P("@i", N(c.Icon)), SqlDb.P("@d", N(c.Description)), SqlDb.P("@m", N(c.Meeting)),
                SqlDb.P("@l", N(c.Location)), SqlDb.P("@a", N(c.Advisor)), SqlDb.P("@p", N(c.President)), SqlDb.P("@b", c.BaseMembers));
        }
    }
}
