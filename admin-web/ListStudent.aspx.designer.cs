namespace MyfschoolWeb
{
    public partial class ListStudent
    {
        protected global::System.Web.UI.WebControls.Literal litSubtitle;
        protected global::System.Web.UI.WebControls.PlaceHolder phAdminActions;
        protected global::System.Web.UI.WebControls.LinkButton btnShowAdd;
        protected global::System.Web.UI.WebControls.Panel pnlStatusAlert;
        protected global::System.Web.UI.WebControls.Literal litStatusMessage;

        protected global::System.Web.UI.WebControls.Panel pnlForm;
        protected global::System.Web.UI.WebControls.HiddenField hfEditId;
        protected global::System.Web.UI.WebControls.Literal litFormTitle;
        protected global::System.Web.UI.WebControls.DropDownList ddlFormRole;
        protected global::System.Web.UI.WebControls.TextBox txtName;
        protected global::System.Web.UI.WebControls.TextBox txtClass;
        protected global::System.Web.UI.WebControls.TextBox txtPhone;
        protected global::System.Web.UI.WebControls.TextBox txtEmail;
        protected global::System.Web.UI.WebControls.PlaceHolder phPassword;
        protected global::System.Web.UI.WebControls.TextBox txtPassword;
        protected global::System.Web.UI.WebControls.Button btnSaveUser;
        protected global::System.Web.UI.WebControls.Button btnCancelForm;

        protected global::System.Web.UI.WebControls.Panel pnlPwd;
        protected global::System.Web.UI.WebControls.HiddenField hfPwdId;
        protected global::System.Web.UI.WebControls.Literal litPwdTarget;
        protected global::System.Web.UI.WebControls.TextBox txtResetPwd;
        protected global::System.Web.UI.WebControls.Button btnDoReset;
        protected global::System.Web.UI.WebControls.Button btnCancelPwd;

        protected global::System.Web.UI.WebControls.Panel pnlLinks;
        protected global::System.Web.UI.WebControls.HiddenField hfLinkId;
        protected global::System.Web.UI.WebControls.Literal litLinkTitle;
        protected global::System.Web.UI.WebControls.GridView gvLinks;
        protected global::System.Web.UI.WebControls.Literal litLinkHint;
        protected global::System.Web.UI.WebControls.TextBox txtLinkWho;
        protected global::System.Web.UI.WebControls.Button btnAddLink;
        protected global::System.Web.UI.WebControls.Button btnCloseLinks;

        protected global::System.Web.UI.WebControls.DropDownList ddlRole;
        protected global::System.Web.UI.WebControls.DropDownList ddlClass;
        protected global::System.Web.UI.WebControls.TextBox txtSearch;
        protected global::System.Web.UI.WebControls.Button btnSearch;
        protected global::System.Web.UI.WebControls.Button btnResetFilter;
        protected global::System.Web.UI.WebControls.Literal litStudentCount;
        protected global::System.Web.UI.WebControls.GridView gvStudents;
    }
}
