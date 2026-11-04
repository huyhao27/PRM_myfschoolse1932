using System;

namespace MyfschoolWeb.Models
{
    /// <summary>Role values stored in dbo.Users.role.</summary>
    public static class Roles
    {
        public const string Manager = "Manager";
        public const string Teacher = "GV";
        public const string Parent = "PH";
        public const string Student = "HS";
    }

    /// <summary>
    /// A row of dbo.Users (without the password hash, which never leaves StudentService).
    /// This object is stored in Session["CurrentUser"] after login.
    /// </summary>
    public class UserModel
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Email { get; set; }
        public string Phone { get; set; }
        public string Role { get; set; }
        public string ClassName { get; set; }
        public DateTime? CreatedAt { get; set; }

        public bool IsManager { get { return Role == Roles.Manager; } }
        public bool IsTeacher { get { return Role == Roles.Teacher; } }

        // ------------------------------------------------------------------
        // Legacy members from the old MongoDB model. They only exist so that
        // pages/services that are not migrated yet still compile. They are NOT
        // stored in SQL (except as aliases below). Remove them when migrating.
        // ------------------------------------------------------------------
        [Obsolete("Use Name")]
        public string FullName { get { return Name; } set { Name = value; } }
        [Obsolete("Use Phone")]
        public string PhoneNumber { get { return Phone; } set { Phone = value; } }
        private string _legacyStudentId;
        [Obsolete("Use Id (int)")]
        public string StudentId { get { return _legacyStudentId ?? Id.ToString(); } set { _legacyStudentId = value; } }
        [Obsolete("Passwords are bcrypt hashed in SQL; not available on the model")]
        public string Password { get; set; }
        [Obsolete] public string Campus { get; set; }
        [Obsolete] public int Grade { get; set; }
        [Obsolete] public string StudentIdLinked { get; set; }
        [Obsolete] public string AvatarUrl { get; set; }
        [Obsolete] public DateTime? UpdatedAt { get; set; }
    }

    public class UserCreationResult
    {
        public bool Success { get; set; }
        public string Message { get; set; }
        public UserModel User { get; set; }
    }

    /// <summary>Outcome of StudentService.TryLogin.</summary>
    public class LoginResult
    {
        public UserModel User { get; set; }
        /// <summary>Vietnamese message to show on the login page (null when successful).</summary>
        public string Error { get; set; }
        public bool Success { get { return User != null; } }
        /// <summary>true when the credentials were right but the role (PH/HS) may not use the portal.</summary>
        public bool PortalDenied { get; set; }
    }
}
