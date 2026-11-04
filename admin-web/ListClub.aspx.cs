using System;
using System.Web.UI;
using MyfschoolWeb.Models;
using MyfschoolWeb.Services;

namespace MyfschoolWeb
{
    public partial class ListClub : Page
    {
        private readonly ClubService _svc = new ClubService();

        protected void Page_Load(object sender, EventArgs e)
        {
            var user = Session["CurrentUser"] as UserModel;
            if (user == null || (!user.IsManager && !user.IsTeacher)) { Response.Redirect("Login.aspx"); return; }
            if (!IsPostBack)
            {
                lnkNew.Visible = user.IsManager;
                string q = Request.QueryString["q"];
                if (!string.IsNullOrWhiteSpace(q)) txtSearch.Text = q.Length > 50 ? q.Substring(0, 50) : q;
                Bind();
            }
        }

        protected void btnSearch_Click(object sender, EventArgs e) { Bind(); }

        private void Bind()
        {
            try
            {
                var rows = _svc.List(txtSearch.Text);
                rptClubs.DataSource = rows;
                rptClubs.DataBind();
                litCount.Text = rows.Count.ToString();
                pnlEmpty.Visible = rows.Count == 0;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("ListClub: " + ex);
                rptClubs.DataSource = null;
                rptClubs.DataBind();
                litCount.Text = "0";
                pnlEmpty.Visible = true;
            }
        }

        protected static string Pending(object n)
        {
            int c = n is int ? (int)n : 0;
            return c > 0 ? "<span class=\"badge bg-warning text-dark\">" + c + "</span>" : "<span class=\"text-muted\">0</span>";
        }
    }
}
