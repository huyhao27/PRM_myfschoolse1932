using System;
using System.Web.UI;
using MyfschoolWeb.Models;

namespace MyfschoolWeb
{
    public partial class SiteMaster : MasterPage
    {
        /// <summary>" active" when the current page (file name without extension) is one of the given pages, else "".</summary>
        protected string Active(params string[] pages)
        {
            string cur = System.IO.Path.GetFileNameWithoutExtension(Request.Path ?? "");
            foreach (var p in pages)
                if (string.Equals(p, cur, StringComparison.OrdinalIgnoreCase)) return " active";
            return "";
        }

        /// <summary> aria-current="page" attribute when the current page is one of the given pages, else "".</summary>
        protected string Cur(params string[] pages)
        {
            return Active(pages).Length > 0 ? " aria-current=\"page\"" : "";
        }

        /// <summary>Sidebar badge with the number of pending requests the signed-in user can handle ("" when 0 or on error). Computed at render time so it is fresh after an approve/reject.</summary>
        protected string PendingBadge()
        {
            int n = 0;
            try
            {
                var u = Session["CurrentUser"] as UserModel;
                if (u != null) n = new MyfschoolWeb.Services.RequestService().CountPending(u);
            }
            catch (Exception ex) { System.Diagnostics.Trace.TraceError("Sidebar pending badge: " + ex); }
            if (n <= 0) return "";
            return "<span class=\"nav-count\" aria-hidden=\"true\">" + n + "</span><span class=\"sr-only\">" + n + " đơn chờ duyệt</span>";
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            var currentUser = Session["CurrentUser"] as UserModel;

            // Authentication guard: only Manager and GV may use the portal.
            if (currentUser == null || (!currentUser.IsManager && !currentUser.IsTeacher))
            {
                Response.Redirect("Login.aspx");
                return;
            }

            if (!IsPostBack)
            {
                phAdminNav.Visible = currentUser.IsManager;
                string name = Server.HtmlEncode(string.IsNullOrEmpty(currentUser.Name) ? currentUser.Email : currentUser.Name);

                if (currentUser.IsManager)
                {
                    litPortalBadge.Text = "Cổng quản lý";
                    litUserIcon.Text = "<i class=\"fa-solid fa-user-shield\"></i>";
                    litUserName.Text = name;
                    litUserBadge.Text = "<span class=\"role-badge is-manager\"><i class=\"fa-solid fa-shield-halved\" aria-hidden=\"true\"></i>Quản lý</span>";
                }
                else
                {
                    litPortalBadge.Text = "Cổng giáo viên";
                    litUserIcon.Text = "<i class=\"fa-solid fa-chalkboard-user\"></i>";
                    litUserName.Text = name;
                    litUserBadge.Text = "<span class=\"role-badge is-teacher\"><i class=\"fa-solid fa-chalkboard-user\" aria-hidden=\"true\"></i>Giáo viên</span>";
                }
            }
        }
    }
}
