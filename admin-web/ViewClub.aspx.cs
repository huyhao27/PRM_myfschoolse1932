using System;
using System.Web.UI;
using System.Web.UI.WebControls;
using MyfschoolWeb.Models;
using MyfschoolWeb.Services;

namespace MyfschoolWeb
{
    public partial class ViewClub : Page
    {
        private readonly ClubService _svc = new ClubService();
        private UserModel _user;
        private int _id;
        private bool _isNew;

        protected void Page_Load(object sender, EventArgs e)
        {
            _user = Session["CurrentUser"] as UserModel;
            if (_user == null || (!_user.IsManager && !_user.IsTeacher)) { Response.Redirect("Login.aspx"); return; }
            if (!int.TryParse(Request.QueryString["id"], out _id)) _id = 0;
            _isNew = Request.QueryString["new"] == "1" && _id == 0;
            if (_isNew && !_user.IsManager) { Response.Redirect("ListClub.aspx"); return; }

            if (!IsPostBack)
            {
                string m = Request.QueryString["msg"];
                if (m == "saved") ShowMsg("success", "Đã lưu thông tin câu lạc bộ.");
                else if (m == "created") ShowMsg("success", "Đã tạo câu lạc bộ mới.");
                else if (m == "approved") ShowMsg("success", "Đã duyệt thành viên.");
                else if (m == "rejected") ShowMsg("success", "Đã từ chối yêu cầu tham gia.");
                else if (m == "gone") ShowMsg("warning", "Yêu cầu này đã được xử lý trước đó.");
                Render(true);
            }
        }

        private void ShowMsg(string kind, string text)
        {
            pnlMsg.CssClass = "alert alert-" + kind;
            litMsg.Text = Server.HtmlEncode(text);
            pnlMsg.Visible = true;
        }

        private void Render(bool fillForm)
        {
            if (_isNew)
            {
                litTitle.Text = "Thêm Câu Lạc Bộ";
                litEditTitle.Text = "Thông tin câu lạc bộ mới";
                litSaveText.Text = "Tạo CLB";
                pnlEdit.Visible = true;
                return;
            }

            ClubRow c = null;
            try { c = _svc.Find(_id); }
            catch (Exception ex) { System.Diagnostics.Trace.TraceError("ViewClub: " + ex); }
            if (c == null)
            {
                pnlNotFound.Visible = true;
                pnlInfo.Visible = false; pnlEdit.Visible = false; pnlMembers.Visible = false;
                return;
            }
            pnlNotFound.Visible = false;
            litTitle.Text = Server.HtmlEncode(c.Name);
            pnlInfo.Visible = true;
            litIcon.Text = Server.HtmlEncode(c.Icon ?? "");
            litName.Text = Server.HtmlEncode(c.Name);
            litMembers.Text = c.MemberCount.ToString();
            litDescription.Text = Server.HtmlEncode(c.Description ?? "");
            litMeeting.Text = Server.HtmlEncode(c.Meeting ?? "-");
            litLocation.Text = Server.HtmlEncode(c.Location ?? "-");
            litAdvisor.Text = Server.HtmlEncode(c.Advisor ?? "-");
            litPresident.Text = Server.HtmlEncode(c.President ?? "-");
            litBreakdown.Text = c.BaseMembers + " + " + c.ApprovedMembers + " (chờ duyệt: " + c.PendingMembers + ")";

            pnlEdit.Visible = _user.IsManager;
            litEditTitle.Text = "Chỉnh sửa thông tin CLB (Quản lý)";
            litSaveText.Text = "Lưu thay đổi";
            if (_user.IsManager && fillForm)
            {
                txtName.Text = c.Name; txtIcon.Text = c.Icon; txtDescription.Text = c.Description;
                txtMeeting.Text = c.Meeting; txtLocation.Text = c.Location; txtAdvisor.Text = c.Advisor;
                txtPresident.Text = c.President; txtBase.Text = c.BaseMembers.ToString();
            }

            var members = _svc.Members(c.Id);
            pnlMembers.Visible = true;
            rptMembers.DataSource = members;
            rptMembers.DataBind();
            pnlNoMembers.Visible = members.Count == 0;
        }

        protected void btnSave_Click(object sender, EventArgs e)
        {
            if (!_user.IsManager) { ShowMsg("danger", "Chỉ Quản lý mới được thay đổi thông tin câu lạc bộ."); Render(false); return; }
            int bm;
            if (!int.TryParse((txtBase.Text ?? "").Trim(), out bm)) { ShowMsg("danger", "Số thành viên gốc phải là số nguyên."); Render(false); return; }
            var c = new ClubRow
            {
                Id = _id, Name = txtName.Text, Icon = txtIcon.Text, Description = txtDescription.Text, Meeting = txtMeeting.Text,
                Location = txtLocation.Text, Advisor = txtAdvisor.Text, President = txtPresident.Text, BaseMembers = bm
            };
            try
            {
                if (_isNew)
                {
                    string err;
                    int newId = _svc.Create(_user, c, out err);
                    if (err != null) { ShowMsg("danger", err); Render(false); return; }
                    Go("ViewClub.aspx?id=" + newId + "&msg=created");
                    return;
                }
                string error = _svc.Update(_user, c);
                if (error != null) { ShowMsg("danger", error); Render(false); return; }
                Go("ViewClub.aspx?id=" + _id + "&msg=saved");
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("ViewClub save: " + ex);
                ShowMsg("danger", "Không thể lưu lúc này, vui lòng thử lại.");
                Render(false);
            }
        }

        protected void rptMembers_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            int uid;
            if (!int.TryParse(Convert.ToString(e.CommandArgument), out uid)) return;
            bool ok;
            try
            {
                ok = e.CommandName == "approve" ? _svc.ApproveMember(_user, _id, uid)
                   : e.CommandName == "reject" ? _svc.RejectMember(_user, _id, uid)
                   : false;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("ViewClub member: " + ex);
                ShowMsg("danger", "Không thể xử lý lúc này, vui lòng thử lại.");
                Render(false);
                return;
            }
            Go("ViewClub.aspx?id=" + _id + "&msg=" + (ok ? (e.CommandName == "approve" ? "approved" : "rejected") : "gone"));
        }

        private void Go(string url)
        {
            Response.Redirect(url, false);
            Context.ApplicationInstance.CompleteRequest();
        }

        protected static string Stamp(object d) { return d is DateTime ? DateTime.SpecifyKind((DateTime)d, DateTimeKind.Utc).ToLocalTime().ToString("dd/MM/yyyy HH:mm") : ""; }

        protected static string StatusBadge(object s)
        {
            return (s as string) == "pending"
                ? "<span class=\"badge bg-warning text-dark\">Chờ duyệt</span>"
                : "<span class=\"badge bg-success\">Đã duyệt</span>";
        }
    }
}
