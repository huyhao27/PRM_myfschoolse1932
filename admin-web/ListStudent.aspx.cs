using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using MyfschoolWeb.Models;
using MyfschoolWeb.Services;

namespace MyfschoolWeb
{
    /// <summary>
    /// Users / students management on dbo.Users. Manager: all roles + create/edit/reset password/delete/parent links.
    /// GV: read-only list of the students of the classes he/she teaches.
    /// </summary>
    public partial class ListStudent : Page
    {
        private readonly StudentService _svc = new StudentService();
        private Dictionary<int, string> _relatives = new Dictionary<int, string>();

        private UserModel Me { get { return Session["CurrentUser"] as UserModel; } }

        protected bool IsManagerView { get { return Me != null && Me.IsManager; } }

        protected bool CanLink(string role) { return role == Roles.Student || role == Roles.Parent; }

        protected void Page_Load(object sender, EventArgs e)
        {
            var me = Me;
            if (me == null || (!me.IsManager && !me.IsTeacher))
            {
                Response.Redirect("Login.aspx");
                return;
            }

            if (!IsPostBack)
            {
                phAdminActions.Visible = me.IsManager;
                litSubtitle.Text = me.IsManager
                    ? "Quản trị tài khoản Học sinh, Giáo viên, Phụ huynh và Quản lý THPT FPT Hà Nội"
                    : "Danh sách học sinh các lớp bạn giảng dạy (chỉ xem)";
                LoadClasses();
                if (!me.IsManager) { ddlRole.SelectedValue = "HS"; ddlRole.Enabled = false; }
                LoadUsers();
            }
        }

        private void LoadClasses()
        {
            ddlClass.Items.Clear();
            ddlClass.Items.Add(new ListItem("Tất cả các lớp", "ALL"));
            foreach (var c in _svc.GetAccessibleClasses(Me)) ddlClass.Items.Add(new ListItem("Lớp " + c, c));
        }

        private void LoadUsers()
        {
            var me = Me;
            string cls = ddlClass.SelectedValue;
            string search = (txtSearch.Text ?? "").Trim();
            List<UserModel> users = me.IsManager
                ? _svc.GetUsers(ddlRole.SelectedValue, cls, search)
                : _svc.GetStudentsFor(me, cls, search);

            _relatives = new Dictionary<int, string>();
            foreach (var kv in _svc.GetParentSummaries(users.Where(u => u.Role == Roles.Student).Select(u => u.Id))) _relatives[kv.Key] = kv.Value;
            foreach (var p in users.Where(u => u.Role == Roles.Parent))
            {
                var kids = _svc.GetChildrenOf(p.Id);
                if (kids.Count > 0) _relatives[p.Id] = string.Join(", ", kids.Select(k => k.Name + (string.IsNullOrEmpty(k.ClassName) ? "" : " (" + k.ClassName + ")")));
            }

            litStudentCount.Text = users.Count.ToString();
            gvStudents.DataSource = users;
            gvStudents.DataBind();
        }

        protected void FilterChanged(object sender, EventArgs e) { LoadUsers(); }
        protected void btnSearch_Click(object sender, EventArgs e) { LoadUsers(); }

        protected void btnResetFilter_Click(object sender, EventArgs e)
        {
            txtSearch.Text = "";
            ddlClass.SelectedValue = "ALL";
            if (Me.IsManager) ddlRole.SelectedValue = "ALL";
            pnlStatusAlert.Visible = false;
            LoadUsers();
        }

        // ------------------------------------------------------------------ grid commands (Manager only)

        protected void gvStudents_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            int id;
            if (!int.TryParse(Convert.ToString(e.CommandArgument), out id)) return;
            string cmd = e.CommandName;
            if (cmd != "edituser" && cmd != "pwd" && cmd != "links" && cmd != "deluser") return;

            if (!IsManagerView) { ShowAlert(false, "Từ chối quyền: chỉ Quản lý mới được thực hiện thao tác này."); return; }
            var u = _svc.GetUserById(id);
            if (u == null) { ShowAlert(false, "Không tìm thấy tài khoản (có thể đã bị xóa)."); LoadUsers(); return; }

            HidePanels();
            switch (cmd)
            {
                case "edituser":
                    hfEditId.Value = u.Id.ToString();
                    litFormTitle.Text = "<i class='fa-solid fa-pen me-2'></i>Sửa tài khoản: " + HttpUtility.HtmlEncode(u.Name);
                    ddlFormRole.SelectedValue = u.Role; ddlFormRole.Enabled = false;
                    txtName.Text = u.Name; txtClass.Text = u.ClassName; txtPhone.Text = u.Phone; txtEmail.Text = u.Email;
                    phPassword.Visible = false;
                    pnlForm.Visible = true;
                    break;
                case "pwd":
                    hfPwdId.Value = u.Id.ToString();
                    litPwdTarget.Text = HttpUtility.HtmlEncode(u.Name + " (" + (u.Phone ?? u.Email) + ")");
                    txtResetPwd.Text = "123456";
                    pnlPwd.Visible = true;
                    break;
                case "links":
                    ShowLinks(u);
                    break;
                case "deluser":
                    var r = _svc.DeleteUserSafe(Me, id);
                    ShowAlert(r.Success, r.Message);
                    if (r.Success) LoadClasses();
                    LoadUsers();
                    return;
            }
        }

        private void HidePanels()
        {
            pnlForm.Visible = false; pnlPwd.Visible = false; pnlLinks.Visible = false; pnlStatusAlert.Visible = false;
        }

        protected void btnCancelPanels_Click(object sender, EventArgs e) { HidePanels(); }

        // ------------------------------------------------------------------ create / edit

        protected void btnShowAdd_Click(object sender, EventArgs e)
        {
            if (!IsManagerView) { ShowAlert(false, "Từ chối quyền: chỉ Quản lý mới được tạo tài khoản."); return; }
            HidePanels();
            hfEditId.Value = "";
            litFormTitle.Text = "<i class='fa-solid fa-user-plus me-2'></i>Thêm tài khoản mới";
            ddlFormRole.Enabled = true; ddlFormRole.SelectedValue = "HS";
            txtName.Text = ""; txtClass.Text = ""; txtPhone.Text = ""; txtEmail.Text = ""; txtPassword.Text = "123456";
            phPassword.Visible = true;
            pnlForm.Visible = true;
        }

        protected void btnSaveUser_Click(object sender, EventArgs e)
        {
            if (!IsManagerView) { ShowAlert(false, "Từ chối quyền: chỉ Quản lý mới được tạo hoặc sửa tài khoản."); return; }
            try
            {
                UserCreationResult r;
                int editId;
                if (int.TryParse(hfEditId.Value, out editId))
                {
                    r = _svc.UpdateUserChecked(Me, new UserModel { Id = editId, Name = txtName.Text, ClassName = txtClass.Text, Phone = txtPhone.Text, Email = txtEmail.Text });
                }
                else
                {
                    r = _svc.CreateUser(new UserModel { Name = txtName.Text, ClassName = txtClass.Text, Phone = txtPhone.Text, Email = txtEmail.Text, Role = ddlFormRole.SelectedValue },
                        Me.Role, string.IsNullOrEmpty(txtPassword.Text) ? null : txtPassword.Text);
                }
                ShowAlert(r.Success, r.Message);
                if (r.Success) { pnlForm.Visible = false; LoadClasses(); }
                LoadUsers();
            }
            catch (Exception ex)
            {
                ShowAlert(false, "Lỗi máy chủ: " + ex.Message);
            }
        }

        // ------------------------------------------------------------------ reset password

        protected void btnDoReset_Click(object sender, EventArgs e)
        {
            int id;
            if (!int.TryParse(hfPwdId.Value, out id)) { pnlPwd.Visible = false; return; }
            var r = _svc.ResetPassword(Me, id, txtResetPwd.Text);
            ShowAlert(r.Success, r.Message);
            if (r.Success) pnlPwd.Visible = false;
        }

        // ------------------------------------------------------------------ parent <-> student links

        private void ShowLinks(UserModel u)
        {
            hfLinkId.Value = u.Id.ToString();
            bool isStudent = u.Role == Roles.Student;
            litLinkTitle.Text = HttpUtility.HtmlEncode((isStudent ? "Phụ huynh của " : "Các con của ") + u.Name);
            litLinkHint.Text = isStudent ? "Thêm phụ huynh (SĐT hoặc email của tài khoản PH):" : "Thêm con (SĐT hoặc email của tài khoản HS):";
            txtLinkWho.Text = "";
            gvLinks.DataSource = isStudent ? _svc.GetParentsOf(u.Id) : _svc.GetChildrenOf(u.Id);
            gvLinks.DataBind();
            pnlLinks.Visible = true;
        }

        protected void btnAddLink_Click(object sender, EventArgs e)
        {
            int id; int.TryParse(hfLinkId.Value, out id);
            var u = _svc.GetUserById(id);
            if (u == null) { pnlLinks.Visible = false; return; }
            var other = _svc.FindByIdentifier(txtLinkWho.Text);
            UserCreationResult r;
            if (other == null) r = new UserCreationResult { Message = "Không tìm thấy tài khoản với số điện thoại/email '" + (txtLinkWho.Text ?? "").Trim() + "'." };
            else r = u.Role == Roles.Student ? _svc.LinkParent(Me, other.Id, u.Id) : _svc.LinkParent(Me, u.Id, other.Id);
            ShowAlert(r.Success, r.Message);
            ShowLinks(u);
            LoadUsers();
        }

        protected void gvLinks_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            if (e.CommandName != "unlink") return;
            int other, id;
            if (!int.TryParse(Convert.ToString(e.CommandArgument), out other) || !int.TryParse(hfLinkId.Value, out id)) return;
            var u = _svc.GetUserById(id);
            if (u == null) return;
            var r = u.Role == Roles.Student ? _svc.UnlinkParent(Me, other, u.Id) : _svc.UnlinkParent(Me, u.Id, other);
            ShowAlert(r.Success, r.Message);
            ShowLinks(u);
            LoadUsers();
        }

        // ------------------------------------------------------------------ view helpers

        private void ShowAlert(bool isSuccess, string message)
        {
            pnlStatusAlert.Visible = true;
            pnlStatusAlert.CssClass = isSuccess
                ? "alert alert-success border-start border-4 border-success alert-dismissible fade show mb-4 shadow-sm"
                : "alert alert-danger border-start border-4 border-danger alert-dismissible fade show mb-4 shadow-sm";
            litStatusMessage.Text = (isSuccess ? "<i class='fa-solid fa-circle-check me-2'></i>" : "<i class='fa-solid fa-circle-exclamation me-2'></i>") + HttpUtility.HtmlEncode(message);
        }

        public string GetRoleBadge(string role)
        {
            switch (role)
            {
                case Roles.Manager:
                    return "<span class=\"badge bg-danger text-white\"><i class=\"fa-solid fa-shield-halved me-1\"></i>Quản lý</span>";
                case Roles.Teacher:
                    return "<span class=\"badge bg-primary text-white\"><i class=\"fa-solid fa-chalkboard-user me-1\"></i>Giáo viên (GV)</span>";
                case Roles.Parent:
                    return "<span class=\"badge bg-warning text-dark\"><i class=\"fa-solid fa-user-group me-1\"></i>Phụ huynh (PH)</span>";
                default:
                    return "<span class=\"badge bg-success text-white\"><i class=\"fa-solid fa-user-graduate me-1\"></i>Học sinh (HS)</span>";
            }
        }

        public string GetRelatives(int id, string role)
        {
            string s;
            return _relatives.TryGetValue(id, out s) ? HttpUtility.HtmlEncode(s) : "<span class='text-muted'>-</span>";
        }

        public string GetViewButtons(string role, string className, int id)
        {
            if (role == Roles.Student)
                return "<a href='ListGrade.aspx?class=" + HttpUtility.UrlEncode(className ?? "") + "' class='btn btn-sm btn-outline-secondary' title='Xem sổ điểm'><i class='fa-solid fa-book-bookmark'></i></a> ";
            if (role == Roles.Teacher)
                return "<a href='ListSchedule.aspx' class='btn btn-sm btn-outline-secondary' title='Xem lịch dạy'><i class='fa-solid fa-calendar-days'></i></a> ";
            return "";
        }
    }
}
