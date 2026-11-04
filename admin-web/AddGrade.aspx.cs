using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Net;
using System.Web.UI;
using System.Web.UI.WebControls;
using MyfschoolWeb.Models;
using MyfschoolWeb.Services;

namespace MyfschoolWeb
{
    public partial class AddGrade : Page
    {
        private readonly GradeService _gradeService = new GradeService();
        private readonly StudentService _studentService = new StudentService();
        private UserModel _user;

        protected void Page_Load(object sender, EventArgs e)
        {
            _user = Session["CurrentUser"] as UserModel;
            if (_user == null || (!_user.IsManager && !_user.IsTeacher)) { Response.Redirect("Login.aspx"); return; }

            pnlOtherSubject.Visible = _user.IsManager;
            if (!IsPostBack)
            {
                foreach (var t in _gradeService.GetTerms()) ddlTerm.Items.Add(new ListItem(GradeService.TermLabel(t), t));
                if (ddlTerm.Items.FindByValue(GradeService.DefaultTerm) != null) ddlTerm.SelectedValue = GradeService.DefaultTerm;
                LoadClasses();
                LoadClassDependent();
            }
        }

        private void LoadClasses()
        {
            ddlClass.Items.Clear();
            foreach (var c in _studentService.GetAccessibleClasses(_user)) ddlClass.Items.Add(new ListItem("Lớp " + c, c));
            if (ddlClass.Items.Count == 0) ShowError("Bạn chưa được phân công lớp nào (không có thời khóa biểu).");
        }

        private void LoadClassDependent()
        {
            string cls = ddlClass.SelectedValue;
            ddlStudent.Items.Clear();
            ddlSubject.Items.Clear();
            if (string.IsNullOrEmpty(cls)) return;
            foreach (var s in _studentService.GetStudentsFor(_user, cls)) ddlStudent.Items.Add(new ListItem(s.Id + " - " + s.Name, s.Id.ToString()));
            foreach (var sub in _gradeService.GetEditableSubjects(_user, cls)) ddlSubject.Items.Add(new ListItem(sub, sub));
            if (ddlStudent.Items.Count == 0) ShowError("Lớp " + cls + " chưa có học sinh.");
            if (ddlSubject.Items.Count == 0 && !_user.IsManager) ShowError("Bạn không dạy môn nào trong lớp " + cls + " nên không thể nhập điểm.");
        }

        protected void ddlClass_SelectedIndexChanged(object sender, EventArgs e)
        {
            LoadClassDependent();
        }

        /// <summary>Blank = no score (null). Throws FormatException for invalid input.</summary>
        private static decimal? ParseScore(string text, string label)
        {
            string t = (text ?? "").Trim().Replace(',', '.');
            if (t.Length == 0) return null;
            decimal d;
            if (!decimal.TryParse(t, NumberStyles.Number, CultureInfo.InvariantCulture, out d) || d < 0m || d > 10m)
                throw new FormatException("Điểm \"" + label + "\" phải là số từ 0 đến 10.");
            return d;
        }

        protected void btnSave_Click(object sender, EventArgs e)
        {
            try
            {
                int studentId;
                if (!int.TryParse(ddlStudent.SelectedValue, out studentId)) { ShowError("Vui lòng chọn học sinh."); return; }

                string subject = _user.IsManager && !string.IsNullOrWhiteSpace(txtSubjectOther.Text) ? txtSubjectOther.Text.Trim() : ddlSubject.SelectedValue;
                if (string.IsNullOrWhiteSpace(subject)) { ShowError("Vui lòng chọn môn học."); return; }
                string term = ddlTerm.SelectedValue;

                var entries = new List<GradeEntry>();
                Action<TextBox, string, string> add = (tb, type, label) =>
                {
                    decimal? v = ParseScore(tb.Text, label);
                    if (v.HasValue) entries.Add(new GradeEntry { Type = type, Weight = GradeService.WeightOf(type), Score = v.Value, Date = DateTime.Today });
                };
                add(txtOral, "Miệng", "Miệng");
                add(txt15a, "15 phút", "15 phút lần 1");
                add(txt15b, "15 phút", "15 phút lần 2");
                add(txt1t, "1 tiết", "1 tiết");
                add(txtGk, "Giữa kỳ", "Giữa kỳ");
                add(txtCk, "Cuối kỳ", "Cuối kỳ");
                if (entries.Count == 0) { ShowError("Vui lòng nhập ít nhất một điểm."); return; }

                var existing = _gradeService.Get(studentId, subject, term);
                if (existing != null)
                {
                    ShowError("Học sinh này đã có điểm môn " + WebUtility.HtmlEncode(subject) + " (" + WebUtility.HtmlEncode(GradeService.TermLabel(term)) + "). Hãy dùng <a class='alert-link' href='EditGrade.aspx?studentId=" + studentId +
                              "&subject=" + Server.UrlEncode(existing.Subject) + "&term=" + Server.UrlEncode(term) + "'>Chỉnh sửa</a> để cập nhật.", true);
                    return;
                }

                string err = _gradeService.Save(_user, studentId, subject, term, entries, txtComment.Text);
                if (err != null) { ShowError(err); return; }
                Response.Redirect("ListGrade.aspx?class=" + Server.UrlEncode(ddlClass.SelectedValue) + "&subject=" + Server.UrlEncode(subject) + "&term=" + Server.UrlEncode(term) + "&msg=saved", false);
                Context.ApplicationInstance.CompleteRequest();
            }
            catch (FormatException ex)
            {
                ShowError(ex.Message);
            }
            catch (System.Threading.ThreadAbortException) { throw; }
            catch (Exception)
            {
                ShowError("Không lưu được điểm. Vui lòng thử lại hoặc liên hệ quản trị.");
            }
        }

        private void ShowError(string msg, bool isHtml = false)
        {
            pnlAlert.Visible = true;
            litAlertMessage.Text = "<i class='fa-solid fa-triangle-exclamation me-2'></i>" + (isHtml ? msg : WebUtility.HtmlEncode(msg));
        }
    }
}
