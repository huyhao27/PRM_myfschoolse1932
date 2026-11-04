using System;
using System.IO;
using System.Text;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using MyfschoolWeb.Models;
using MyfschoolWeb.Services;

namespace MyfschoolWeb
{
    /// <summary>CSV import center. Manager only (a GV is sent to the student list).</summary>
    public partial class ImportData : Page
    {
        private readonly ImportService _importService = new ImportService();

        private UserModel Me { get { return Session["CurrentUser"] as UserModel; } }

        protected void Page_Load(object sender, EventArgs e)
        {
            var me = Me;
            if (me == null) { Response.Redirect("Login.aspx"); return; }
            if (!me.IsManager) { Response.Redirect("ListStudent.aspx"); return; }
        }

        /// <summary>JavaScript string literal (double-quoted, escaped) for the sample CSV text.</summary>
        protected string SampleJs(string text)
        {
            var sb = new StringBuilder("\"");
            foreach (char c in text)
            {
                if (c == '\n') sb.Append("\\n");
                else if (c == '"') sb.Append("\\\"");
                else if (c == '\\') sb.Append("\\\\");
                else if (c == '<') sb.Append("\\u003c");
                else if (c != '\r') sb.Append(c);
            }
            return sb.Append('"').ToString();
        }

        private void Run(FileUpload fu, TextBox txt, Func<UserModel, string, ImportResultModel> action)
        {
            string csv = GetFileOrTextContent(fu, txt);
            if (string.IsNullOrWhiteSpace(csv))
            {
                ShowResult(new ImportResultModel { Success = false, Message = "Vui lòng chọn file CSV hoặc nhập nội dung văn bản." });
                return;
            }
            ShowResult(action(Me, csv));
        }

        protected void btnImportStudents_Click(object sender, EventArgs e) { Run(fuStudents, txtStudentsCsv, _importService.ImportStudentsFromCsv); }
        protected void btnImportSchedules_Click(object sender, EventArgs e) { Run(fuSchedules, txtSchedulesCsv, _importService.ImportSchedulesFromCsv); }
        protected void btnImportGrades_Click(object sender, EventArgs e) { Run(fuGrades, txtGradesCsv, _importService.ImportGradesFromCsv); }
        protected void btnQuickSeed_Click(object sender, EventArgs e) { ShowResult(_importService.SeedDemoData(Me)); }

        protected void lnkTplStudents_Click(object sender, EventArgs e) { Download("mau-tai-khoan.csv", ImportService.StudentsTemplate); }
        protected void lnkTplSchedules_Click(object sender, EventArgs e) { Download("mau-thoi-khoa-bieu.csv", ImportService.SchedulesTemplate); }
        protected void lnkTplGrades_Click(object sender, EventArgs e) { Download("mau-diem.csv", ImportService.GradesTemplate); }

        private void Download(string fileName, string content)
        {
            Response.Clear();
            Response.ContentType = "text/csv";
            Response.ContentEncoding = new UTF8Encoding(true);
            Response.Charset = "utf-8";
            Response.AddHeader("Content-Disposition", "attachment; filename=" + fileName);
            Response.BinaryWrite(new UTF8Encoding(true).GetPreamble());
            Response.BinaryWrite(Encoding.UTF8.GetBytes(content.Replace("\n", "\r\n")));
            Response.Flush();
            Response.End();
        }

        private string GetFileOrTextContent(FileUpload fu, TextBox txt)
        {
            if (fu.HasFile)
            {
                if (fu.PostedFile.ContentLength > 5 * 1024 * 1024) return "";
                using (var reader = new StreamReader(fu.FileContent, Encoding.UTF8, true)) return reader.ReadToEnd();
            }
            return txt.Text;
        }

        private void ShowResult(ImportResultModel result)
        {
            string color = result.Success ? "success" : (result.InsertedCount + result.UpdatedCount > 0 ? "warning" : "danger");
            pnlResult.Visible = true;
            pnlResult.CssClass = "card card-custom p-3 mb-4 border-start border-4 border-" + color;
            litResultSummary.Text = "<span class='text-" + color + "'><i class='fa-solid " + (result.Success ? "fa-circle-check" : "fa-triangle-exclamation") + " me-2'></i>" + HttpUtility.HtmlEncode(result.Message) + "</span>";
            litResultStats.Text = "Tổng số dòng xử lý: <strong>" + result.TotalProcessed + "</strong> | Thêm mới: <strong class='text-success'>" + result.InsertedCount +
                                  "</strong> | Cập nhật: <strong class='text-primary'>" + result.UpdatedCount + "</strong> | Lỗi: <strong class='text-danger'>" + result.FailedCount + "</strong>";

            var sb = new StringBuilder();
            if (result.ErrorDetails != null && result.ErrorDetails.Count > 0)
            {
                sb.Append("<div class='text-danger small'><strong>Các dòng bị bỏ qua:</strong><ul class='mb-2'>");
                foreach (var err in result.ErrorDetails) sb.Append("<li>").Append(HttpUtility.HtmlEncode(err)).Append("</li>");
                sb.Append("</ul></div>");
            }
            if (result.ImportedItems != null && result.ImportedItems.Count > 0)
            {
                sb.Append("<div class='small fw-semibold text-muted mb-1'>Chi tiết:</div><ul class='list-group list-group-flush small' style='max-height:260px;overflow:auto'>");
                foreach (var item in result.ImportedItems)
                    sb.Append("<li class='list-group-item py-1'><i class='fa-solid fa-check text-success me-2'></i>").Append(HttpUtility.HtmlEncode(item)).Append("</li>");
                sb.Append("</ul>");
            }
            litResultDetails.Text = sb.ToString();
            pnlDetails.Visible = sb.Length > 0;
        }
    }
}
