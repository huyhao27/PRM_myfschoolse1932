using System;
using MyfschoolWeb.Services;

namespace MyfschoolWeb
{
    public partial class Login : System.Web.UI.Page
    {
        private readonly StudentService _studentService = new StudentService();

        protected void Page_Load(object sender, EventArgs e)
        {
            if (Request.QueryString["logout"] == "true")
            {
                Session.Clear();
                Session.Abandon();
            }

            if (!IsPostBack)
            {
                txtIdentifier.Text = "";
                txtPassword.Text = "";
            }
        }

        protected void btnLogin_Click(object sender, EventArgs e)
        {
            string id = txtIdentifier.Text == null ? "" : txtIdentifier.Text.Trim();
            string pass = txtPassword.Text ?? "";

            if (id.Length == 0 || pass.Length == 0)
            {
                ShowError("Vui lòng nhập đầy đủ số điện thoại và mật khẩu.");
                return;
            }

            Models.LoginResult result;
            try
            {
                result = _studentService.TryLogin(id, pass);
            }
            catch (Exception ex)
            {
                ShowError("Không kết nối được cơ sở dữ liệu: " + Server.HtmlEncode(ex.Message));
                return;
            }

            if (result.Success)
            {
                Session["CurrentUser"] = result.User;
                Response.Redirect("Default.aspx");
            }
            else
            {
                ShowError(Server.HtmlEncode(result.Error));
            }
        }

        private void ShowError(string msg)
        {
            pnlAlert.Visible = true;
            litAlert.Text = "<i class='fa-solid fa-triangle-exclamation' aria-hidden='true'></i><span class='alert-text'>" + msg + "</span>";
        }
    }
}
