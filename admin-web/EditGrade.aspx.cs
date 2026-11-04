using System;
using System.Collections.Generic;
using System.Globalization;
using System.Net;
using System.Web.UI;
using System.Web.UI.WebControls;
using MyfschoolWeb.Models;
using MyfschoolWeb.Services;

namespace MyfschoolWeb
{
    /// <summary>EditGrade.aspx?studentId=3&amp;subject=Toán&amp;term=HK1 : replaces the score rows of that student+subject+term.</summary>
    public partial class EditGrade : Page
    {
        private readonly GradeService _gradeService = new GradeService();
        private UserModel _user;
        private int _studentId;
        private string _subject;
        private string _term;
        private GradeModel _grade;

        /// <summary>Row shown in the repeater.</summary>
        public class RowVm
        {
            public string Type { get; set; }
            public string ScoreText { get; set; }
            public string DateText { get; set; }
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            _user = Session["CurrentUser"] as UserModel;
            if (_user == null || (!_user.IsManager && !_user.IsTeacher)) { Response.Redirect("Login.aspx"); return; }

            _subject = Request.QueryString["subject"];
            _term = Request.QueryString["term"];
            if (string.IsNullOrWhiteSpace(_term)) _term = GradeService.DefaultTerm;
            if (!int.TryParse(Request.QueryString["studentId"], out _studentId) || string.IsNullOrWhiteSpace(_subject))
            {
                Block("Thiếu thông tin: cần có studentId, subject và term trên đường dẫn. Hãy mở từ <a class='alert-link' href='ListGrade.aspx'>Sổ điểm</a>.");
                return;
            }

            try { _grade = _gradeService.Get(_studentId, _subject, _term); }
            catch (Exception) { Block("Không tải được dữ liệu điểm. Vui lòng thử lại."); return; }

            if (_grade == null) { Block("Không tìm thấy bảng điểm của học sinh này cho môn và học kỳ đã chọn. Dùng <a class='alert-link' href='AddGrade.aspx'>Nhập điểm</a> để tạo mới."); return; }
            if (!_gradeService.CanView(_user, _grade.ClassName)) { Block("Bạn không có quyền với lớp " + WebUtility.HtmlEncode(_grade.ClassName ?? "") + "."); return; }
            if (!_gradeService.CanEdit(_user, _grade.ClassName, _grade.Subject)) { Block("Bạn chỉ được sửa điểm môn mình giảng dạy (theo thời khóa biểu). Bạn vẫn có thể <a class='alert-link' href='ViewGrade.aspx?studentId=" + _studentId + "&subject=" + Server.UrlEncode(_grade.Subject) + "&term=" + Server.UrlEncode(_term) + "'>xem điểm</a>."); return; }

            if (!IsPostBack)
            {
                txtStudentId.Text = _grade.StudentId.ToString();
                txtStudentName.Text = _grade.StudentName;
                txtClassName.Text = _grade.ClassName;
                txtSubject.Text = _grade.Subject;
                txtTerm.Text = GradeService.TermLabel(_grade.Term);
                txtComment.Text = _grade.Comment;
                var rows = new List<RowVm>();
                foreach (var en in _grade.Entries)
                    rows.Add(new RowVm { Type = en.Type, ScoreText = en.Score.ToString("0.##", CultureInfo.InvariantCulture), DateText = en.Date.HasValue ? en.Date.Value.ToString("yyyy-MM-dd") : "" });
                Bind(rows);
            }
        }

        private void Block(string html)
        {
            pnlForm.Visible = false;
            ShowError(html, true);
        }

        private void Bind(List<RowVm> rows)
        {
            rptRows.DataSource = rows;
            rptRows.DataBind();
        }

        protected void rptRows_ItemDataBound(object sender, RepeaterItemEventArgs e)
        {
            var vm = e.Item.DataItem as RowVm;
            if (vm == null) return;
            var ddl = (DropDownList)e.Item.FindControl("ddlType");
            foreach (var t in GradeService.Types) ddl.Items.Add(new ListItem(t + " (x" + GradeService.WeightOf(t) + ")", t));
            if (ddl.Items.FindByValue(vm.Type) != null) ddl.SelectedValue = vm.Type;
        }

        /// <summary>Read the repeater rows. Rows ticked for deletion are skipped.</summary>
        private List<RowVm> ReadRows(bool dropDeleted)
        {
            var rows = new List<RowVm>();
            foreach (RepeaterItem it in rptRows.Items)
            {
                bool del = ((CheckBox)it.FindControl("chkDel")).Checked;
                if (del && dropDeleted) continue;
                rows.Add(new RowVm
                {
                    Type = ((DropDownList)it.FindControl("ddlType")).SelectedValue,
                    ScoreText = ((TextBox)it.FindControl("txtScore")).Text.Trim(),
                    DateText = ((TextBox)it.FindControl("txtDate")).Text.Trim()
                });
            }
            return rows;
        }

        protected void btnAddRow_Click(object sender, EventArgs e)
        {
            if (_grade == null) return;
            var rows = ReadRows(true);
            rows.Add(new RowVm { Type = "15 phút", ScoreText = "", DateText = DateTime.Today.ToString("yyyy-MM-dd") });
            Bind(rows);
        }

        protected void btnUpdate_Click(object sender, EventArgs e)
        {
            if (_grade == null) return;
            try
            {
                var entries = new List<GradeEntry>();
                foreach (var r in ReadRows(true))
                {
                    if (r.ScoreText.Length == 0) continue; // blank score row = ignored
                    decimal d;
                    if (!decimal.TryParse(r.ScoreText.Replace(',', '.'), NumberStyles.Number, CultureInfo.InvariantCulture, out d) || d < 0m || d > 10m)
                    {
                        ShowError("Điểm \"" + r.ScoreText + "\" không hợp lệ: nhập số từ 0 đến 10.");
                        return;
                    }
                    DateTime dt;
                    DateTime? date = DateTime.TryParseExact(r.DateText, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out dt) ? dt : (DateTime?)null;
                    entries.Add(new GradeEntry { Type = r.Type, Score = d, Date = date });
                }
                if (entries.Count == 0)
                {
                    ShowError("Cần ít nhất một điểm. Muốn xóa toàn bộ bảng điểm, hãy dùng nút xóa trong Sổ điểm.");
                    return;
                }
                string err = _gradeService.Save(_user, _grade.StudentId, _grade.Subject, _grade.Term, entries, txtComment.Text);
                if (err != null) { ShowError(err); return; }
                Response.Redirect("ListGrade.aspx?class=" + Server.UrlEncode(_grade.ClassName) + "&subject=" + Server.UrlEncode(_grade.Subject) + "&term=" + Server.UrlEncode(_grade.Term) + "&msg=saved", false);
                Context.ApplicationInstance.CompleteRequest();
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
