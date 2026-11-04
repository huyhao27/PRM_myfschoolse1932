using System;
using System.Web.UI;
using MyfschoolWeb.Models;
using MyfschoolWeb.Services;

namespace MyfschoolWeb
{
    public partial class ViewRequest : Page
    {
        private readonly RequestService _svc = new RequestService();
        private UserModel _user;
        private int _id;

        protected void Page_Load(object sender, EventArgs e)
        {
            _user = Session["CurrentUser"] as UserModel;
            if (_user == null || (!_user.IsManager && !_user.IsTeacher)) { Response.Redirect("Login.aspx"); return; }
            if (!int.TryParse(Request.QueryString["id"], out _id)) _id = 0;

            if (!IsPostBack)
            {
                string m = Request.QueryString["msg"];
                if (m == "approved") ShowMsg("success", "Đã duyệt đơn từ.");
                else if (m == "rejected") ShowMsg("success", "Đã từ chối đơn từ.");
                else if (m == "already") ShowMsg("warning", "Đơn này đã được xử lý trước đó, không thể xử lý lại.");
                Render();
            }
        }

        private void ShowMsg(string kind, string text)
        {
            pnlMsg.CssClass = "alert alert-" + kind;
            litMsg.Text = Server.HtmlEncode(text);
            pnlMsg.Visible = true;
        }

        private void Render()
        {
            RequestRow r = null;
            try { r = _svc.FindVisible(_user, _id); }
            catch (Exception ex) { System.Diagnostics.Trace.TraceError("ViewRequest: " + ex); }
            if (r == null)
            {
                pnlDetail.Visible = false;
                pnlNotFound.Visible = true;
                return;
            }
            pnlNotFound.Visible = false;
            pnlDetail.Visible = true;
            litType.Text = Server.HtmlEncode(r.Type);
            litStatus.Text = "<span class=\"" + RequestService.StatusBadgeClass(r.Status) + " fs-6\">" + RequestService.StatusText(r.Status) + "</span>";
            litStudent.Text = Server.HtmlEncode(r.StudentName) + " <span class=\"text-muted small\">(Mã " + r.StudentId + ")</span>";
            litClass.Text = Server.HtmlEncode(r.ClassName ?? "");
            litPeriod.Text = ListRequest_Period(r);
            litCreator.Text = Server.HtmlEncode(r.CreatorName) + " (" + Server.HtmlEncode(RequestService.RoleText(r.CreatorRole)) + ") - " + DateTime.SpecifyKind(r.CreatedAt, DateTimeKind.Utc).ToLocalTime().ToString("dd/MM/yyyy HH:mm");
            litReason.Text = Server.HtmlEncode(r.Reason);

            bool pending = r.Status == "pending";
            pnlDecide.Visible = pending;
            pnlHandled.Visible = !pending;
            if (!pending)
            {
                litHandledBy.Text = Server.HtmlEncode(r.HandledByName ?? "-");
                litHandledAt.Text = r.HandledAt.HasValue ? DateTime.SpecifyKind(r.HandledAt.Value, DateTimeKind.Utc).ToLocalTime().ToString("dd/MM/yyyy HH:mm") : "-";
                litComment.Text = string.IsNullOrEmpty(r.TeacherComment) ? "<span class=\"text-muted\">(Không có nhận xét)</span>" : Server.HtmlEncode(r.TeacherComment);
            }
        }

        private static string ListRequest_Period(RequestRow r)
        {
            if (r.FromDate == null) return "-";
            string a = r.FromDate.Value.ToString("dd/MM/yyyy");
            if (r.ToDate == null || r.ToDate.Value.Date == r.FromDate.Value.Date) return a;
            return a + " - " + r.ToDate.Value.ToString("dd/MM/yyyy");
        }

        protected void btnApprove_Click(object sender, EventArgs e) { Decide("approved"); }
        protected void btnReject_Click(object sender, EventArgs e) { Decide("rejected"); }

        private void Decide(string decision)
        {
            string comment = (txtComment.Text ?? "").Trim();
            if (comment.Length > RequestService.MaxComment)
            {
                ShowMsg("danger", "Nhận xét tối đa " + RequestService.MaxComment + " ký tự.");
                Render();
                return;
            }
            DecideResult res;
            try { res = _svc.Decide(_user, _id, decision, comment); }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("ViewRequest decide: " + ex);
                ShowMsg("danger", "Không thể xử lý đơn lúc này, vui lòng thử lại.");
                Render();
                return;
            }
            switch (res)
            {
                case DecideResult.Done:
                    Response.Redirect("ViewRequest.aspx?id=" + _id + "&msg=" + decision, false);
                    Context.ApplicationInstance.CompleteRequest();
                    return;
                case DecideResult.AlreadyHandled:
                    Response.Redirect("ViewRequest.aspx?id=" + _id + "&msg=already", false);
                    Context.ApplicationInstance.CompleteRequest();
                    return;
                case DecideResult.NotFound:
                    ShowMsg("danger", "Không tìm thấy đơn từ hoặc bạn không có quyền xử lý.");
                    break;
                default:
                    ShowMsg("danger", "Yêu cầu không hợp lệ.");
                    break;
            }
            Render();
        }
    }
}
