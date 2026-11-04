using System;
using System.Linq;
using System.Net;
using System.Web.UI;
using MyfschoolWeb.Models;
using MyfschoolWeb.Services;

namespace MyfschoolWeb
{
    /// <summary>ViewGrade.aspx?studentId=3&amp;subject=Toán&amp;term=HK1</summary>
    public partial class ViewGrade : Page
    {
        private readonly GradeService _gradeService = new GradeService();

        protected void Page_Load(object sender, EventArgs e)
        {
            var user = Session["CurrentUser"] as UserModel;
            if (user == null || (!user.IsManager && !user.IsTeacher)) { Response.Redirect("Login.aspx"); return; }
            if (IsPostBack) return;

            int studentId;
            string subject = Request.QueryString["subject"];
            string term = Request.QueryString["term"];
            if (string.IsNullOrWhiteSpace(term)) term = GradeService.DefaultTerm;
            if (!int.TryParse(Request.QueryString["studentId"], out studentId) || string.IsNullOrWhiteSpace(subject))
            {
                Fail("Thiếu thông tin: cần có studentId, subject và term trên đường dẫn. Hãy mở phiếu điểm từ <a href='ListGrade.aspx'>Sổ điểm</a>.");
                return;
            }

            GradeModel g;
            try { g = _gradeService.Get(studentId, subject, term); }
            catch (Exception) { Fail("Không tải được dữ liệu điểm. Vui lòng thử lại."); return; }

            if (g == null) { Fail("Không tìm thấy bảng điểm của học sinh này cho môn và học kỳ đã chọn. <a href='ListGrade.aspx'>Quay lại sổ điểm</a>."); return; }
            if (!_gradeService.CanView(user, g.ClassName)) { Fail("Bạn không có quyền xem điểm của lớp " + WebUtility.HtmlEncode(g.ClassName ?? "") + "."); return; }

            litTerm.Text = WebUtility.HtmlEncode(GradeService.TermLabel(g.Term));
            litStudentName.Text = WebUtility.HtmlEncode(g.StudentName);
            litStudentId.Text = g.StudentId.ToString();
            litClassName.Text = WebUtility.HtmlEncode(g.ClassName);
            litSubject.Text = WebUtility.HtmlEncode(g.Subject);
            litTeacherName.Text = WebUtility.HtmlEncode(string.IsNullOrEmpty(g.TeacherName) ? "(chưa có)" : g.TeacherName);

            rptEntries.DataSource = g.Entries;
            rptEntries.DataBind();

            litAverage.Text = g.AverageText;
            litLevel.Text = WebUtility.HtmlEncode(g.Evaluation);
            litBadgeClass.Text = g.BadgeClass;

            int totalW = g.Entries.Sum(x => x.Weight);
            decimal sum = g.Entries.Sum(x => x.Score * x.Weight);
            litFormulaCalc.Text = string.Format(System.Globalization.CultureInfo.InvariantCulture, "{0:0.##} / {1} = {2}", sum, totalW, g.AverageText);

            string conduct = _gradeService.GetConduct(g.StudentId, g.Term);
            litConduct.Text = WebUtility.HtmlEncode(string.IsNullOrEmpty(conduct) ? "-" : conduct);
            litComment.Text = WebUtility.HtmlEncode(string.IsNullOrEmpty(g.Comment) ? "Chưa có nhận xét." : g.Comment);
            litSignStudent.Text = WebUtility.HtmlEncode(g.StudentName);
            litSignTeacher.Text = WebUtility.HtmlEncode(g.TeacherName ?? "");

            if (_gradeService.CanEdit(user, g.ClassName, g.Subject))
            {
                lnkEdit.Visible = true;
                lnkEdit.NavigateUrl = "EditGrade.aspx?studentId=" + g.StudentId + "&subject=" + Server.UrlEncode(g.Subject) + "&term=" + Server.UrlEncode(g.Term);
            }
        }

        private void Fail(string html)
        {
            pnlCard.Visible = false;
            pnlMessage.Visible = true;
            litMessage.Text = html;
        }
    }
}
