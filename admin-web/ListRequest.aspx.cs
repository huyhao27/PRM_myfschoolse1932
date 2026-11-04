using System;
using System.Web.UI;
using System.Web.UI.WebControls;
using MyfschoolWeb.Models;
using MyfschoolWeb.Services;

namespace MyfschoolWeb
{
    public partial class ListRequest : Page
    {
        private readonly RequestService _svc = new RequestService();

        protected void Page_Load(object sender, EventArgs e)
        {
            var user = Session["CurrentUser"] as UserModel;
            if (user == null || (!user.IsManager && !user.IsTeacher)) { Response.Redirect("Login.aspx"); return; }

            if (!IsPostBack)
            {
                ddlType.Items.Add(new ListItem("Tất cả loại đơn", "ALL"));
                foreach (var t in RequestService.Types) ddlType.Items.Add(new ListItem(t, t));

                string status = Request.QueryString["status"];
                if (status != null && ddlStatus.Items.FindByValue(status) != null) ddlStatus.SelectedValue = status;
                string type = Request.QueryString["type"];
                if (type != null && ddlType.Items.FindByValue(type) != null) ddlType.SelectedValue = type;
                string q = Request.QueryString["q"];
                if (!string.IsNullOrWhiteSpace(q)) txtSearch.Text = q.Length > 100 ? q.Substring(0, 100) : q;

                litScope.Text = user.IsManager
                    ? "Quản lý xem đơn từ của toàn bộ học sinh trong trường."
                    : "Giáo viên xem đơn từ của học sinh các lớp mình dạy.";
                Bind(user);
            }
        }

        protected void FilterChanged(object sender, EventArgs e)
        {
            var user = Session["CurrentUser"] as UserModel;
            if (user == null) { Response.Redirect("Login.aspx"); return; }
            Bind(user);
        }

        private void Bind(UserModel user)
        {
            try
            {
                var rows = _svc.List(user, ddlStatus.SelectedValue, ddlType.SelectedValue, txtSearch.Text);
                rptRequests.DataSource = rows;
                rptRequests.DataBind();
                litCount.Text = rows.Count.ToString();
                pnlEmpty.Visible = rows.Count == 0;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("ListRequest: " + ex);
                rptRequests.DataSource = null;
                rptRequests.DataBind();
                litCount.Text = "0";
                pnlEmpty.Visible = true;
            }
        }

        protected static string Badge(object status) { return RequestService.StatusBadgeClass(status as string); }
        protected static string StatusText(object status) { return RequestService.StatusText(status as string); }
        protected string RoleText(object role) { return Server.HtmlEncode(RequestService.RoleText(role as string)); }
        protected static string Stamp(object d) { return d is DateTime ? DateTime.SpecifyKind((DateTime)d, DateTimeKind.Utc).ToLocalTime().ToString("dd/MM/yyyy HH:mm") : ""; }

        protected static string Period(object item)
        {
            var r = item as RequestRow;
            if (r == null || r.FromDate == null) return "";
            string a = r.FromDate.Value.ToString("dd/MM/yyyy");
            if (r.ToDate == null || r.ToDate.Value.Date == r.FromDate.Value.Date) return a;
            return a + " - " + r.ToDate.Value.ToString("dd/MM/yyyy");
        }
    }
}
