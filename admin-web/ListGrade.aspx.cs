using System;
using System.Collections.Generic;
using System.Net;
using System.Web.UI;
using System.Web.UI.WebControls;
using MyfschoolWeb.Models;
using MyfschoolWeb.Services;

namespace MyfschoolWeb
{
    public partial class ListGrade : Page
    {
        private readonly GradeService _gradeService = new GradeService();
        private readonly StudentService _studentService = new StudentService();
        private UserModel _user;
        private readonly Dictionary<string, bool> _editCache = new Dictionary<string, bool>();

        protected void Page_Load(object sender, EventArgs e)
        {
            _user = Session["CurrentUser"] as UserModel;
            if (_user == null || (!_user.IsManager && !_user.IsTeacher)) { Response.Redirect("Login.aspx"); return; }

            if (!IsPostBack)
            {
                LoadDropdowns();
                if (Request.QueryString["msg"] == "saved") ShowOk("Đã lưu điểm.");
                else if (Request.QueryString["msg"] == "deleted") ShowOk("Đã xóa bảng điểm.");
                LoadGrades();
            }
        }

        private static void Select(DropDownList ddl, string value)
        {
            if (!string.IsNullOrEmpty(value) && ddl.Items.FindByValue(value) != null) ddl.SelectedValue = value;
        }

        private void LoadDropdowns()
        {
            ddlClass.Items.Clear();
            ddlClass.Items.Add(new ListItem("Tất cả các lớp", "ALL"));
            foreach (var c in _studentService.GetAccessibleClasses(_user)) ddlClass.Items.Add(new ListItem("Lớp " + c, c));
            Select(ddlClass, Request.QueryString["class"]);

            ddlSubject.Items.Clear();
            ddlSubject.Items.Add(new ListItem("Tất cả các môn", "ALL"));
            foreach (var s in _gradeService.GetFilterSubjects(_user)) ddlSubject.Items.Add(new ListItem(s, s));
            Select(ddlSubject, Request.QueryString["subject"]);

            ddlTerm.Items.Clear();
            ddlTerm.Items.Add(new ListItem("Tất cả học kỳ", "ALL"));
            foreach (var t in _gradeService.GetTerms()) ddlTerm.Items.Add(new ListItem(GradeService.TermLabel(t), t));
            ddlTerm.SelectedValue = GradeService.DefaultTerm;
            Select(ddlTerm, Request.QueryString["term"]);

            if (!string.IsNullOrEmpty(Request.QueryString["q"])) txtSearch.Text = Request.QueryString["q"];
        }

        private void LoadGrades()
        {
            List<GradeModel> grades;
            try
            {
                grades = _gradeService.GetGradebook(_user, ddlClass.SelectedValue, ddlSubject.SelectedValue, ddlTerm.SelectedValue, txtSearch.Text);
            }
            catch (Exception)
            {
                grades = new List<GradeModel>();
                ShowErr("Không tải được dữ liệu điểm. Vui lòng thử lại.");
            }
            litRecordCount.Text = grades.Count.ToString();
            gvGrades.DataSource = grades;
            gvGrades.DataBind();
        }

        protected void FilterChanged(object sender, EventArgs e) { LoadGrades(); }

        protected void btnSearch_Click(object sender, EventArgs e) { LoadGrades(); }

        private bool CanEditCached(string cls, string subject)
        {
            string k = cls + "|" + subject;
            bool v;
            if (!_editCache.TryGetValue(k, out v)) { v = _gradeService.CanEdit(_user, cls, subject); _editCache[k] = v; }
            return v;
        }

        protected void gvGrades_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType != DataControlRowType.DataRow) return;
            var g = e.Row.DataItem as GradeModel;
            if (g == null) return;
            string qs = "studentId=" + g.StudentId + "&subject=" + Server.UrlEncode(g.Subject) + "&term=" + Server.UrlEncode(g.Term);
            var view = (HyperLink)e.Row.FindControl("lnkView");
            var edit = (HyperLink)e.Row.FindControl("lnkEdit");
            var del = (LinkButton)e.Row.FindControl("btnDelete");
            view.NavigateUrl = "ViewGrade.aspx?" + qs;
            edit.NavigateUrl = "EditGrade.aspx?" + qs;
            bool can = CanEditCached(g.ClassName, g.Subject);
            edit.Visible = can;
            del.Visible = can;
            del.CommandArgument = g.StudentId + "|" + g.Subject + "|" + g.Term;
        }

        protected void gvGrades_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            if (e.CommandName != "DeleteGrade") return;
            string[] parts = (e.CommandArgument ?? "").ToString().Split('|');
            int sid;
            if (parts.Length < 3 || !int.TryParse(parts[0], out sid)) { ShowErr("Yêu cầu không hợp lệ."); return; }
            string term = parts[parts.Length - 1];
            string subject = string.Join("|", parts, 1, parts.Length - 2);
            string err;
            try { err = _gradeService.Delete(_user, sid, subject, term); }
            catch (Exception) { err = "Không xóa được bảng điểm. Vui lòng thử lại."; }
            if (err != null) ShowErr(err); else ShowOk("Đã xóa bảng điểm khỏi hệ thống.");
            LoadGrades();
        }

        private void ShowOk(string msg)
        {
            pnlAlert.CssClass = "alert alert-success alert-dismissible fade show";
            pnlAlert.Visible = true;
            litAlertMessage.Text = "<i class='fa-solid fa-check-circle me-2'></i>" + WebUtility.HtmlEncode(msg);
        }

        private void ShowErr(string msg)
        {
            pnlAlert.CssClass = "alert alert-danger alert-dismissible fade show";
            pnlAlert.Visible = true;
            litAlertMessage.Text = "<i class='fa-solid fa-triangle-exclamation me-2'></i>" + WebUtility.HtmlEncode(msg);
        }
    }
}
