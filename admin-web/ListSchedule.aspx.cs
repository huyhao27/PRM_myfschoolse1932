using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using MyfschoolWeb.Models;
using MyfschoolWeb.Services;

namespace MyfschoolWeb
{
    /// <summary>Timetable. Manager: all classes, add/edit/delete. GV: only the lessons he/she teaches (read-only).</summary>
    public partial class ListSchedule : Page
    {
        private readonly ScheduleService _svc = new ScheduleService();

        private UserModel Me { get { return Session["CurrentUser"] as UserModel; } }
        protected bool IsManagerView { get { return Me != null && Me.IsManager; } }

        protected void Page_Load(object sender, EventArgs e)
        {
            var me = Me;
            if (me == null || (!me.IsManager && !me.IsTeacher)) { Response.Redirect("Login.aspx"); return; }
            if (IsPostBack) return;

            phManagerActions.Visible = me.IsManager;
            litSubtitle.Text = me.IsManager ? "Quản lý lịch học, phòng học và giáo viên giảng dạy THPT FPT Hà Nội"
                                            : "Các tiết học bạn đang giảng dạy (chỉ xem)";

            ddlDay.Items.Add(new ListItem("Tất cả các thứ", "0"));
            ddlFormDay.Items.Clear();
            for (int d = 1; d <= 7; d++)
            {
                ddlDay.Items.Add(new ListItem(ScheduleService.DayName(d), d.ToString()));
                ddlFormDay.Items.Add(new ListItem(ScheduleService.DayName(d), d.ToString()));
            }
            for (int p = 1; p <= ScheduleService.MaxPeriod; p++)
                ddlFormPeriod.Items.Add(new ListItem("Tiết " + p + " (" + ScheduleService.PeriodStart(p) + " - " + ScheduleService.PeriodEnd(p) + ")", p.ToString()));

            ddlClass.Items.Add(new ListItem("Tất cả các lớp", "ALL"));
            var classes = _svc.GetClassesFor(me);
            foreach (var c in classes) ddlClass.Items.Add(new ListItem("Lớp " + c, c));
            string wanted = Request.QueryString["class"];
            if (!string.IsNullOrEmpty(wanted) && ddlClass.Items.FindByValue(wanted) != null) ddlClass.SelectedValue = wanted;
            else if (classes.Count > 0) ddlClass.SelectedValue = classes[0];

            if (me.IsManager)
            {
                ddlFormTeacher.Items.Clear();
                ddlFormTeacher.Items.Add(new ListItem("-- Chọn giáo viên --", "0"));
                foreach (var t in _svc.GetTeachers()) ddlFormTeacher.Items.Add(new ListItem(t.Name + (string.IsNullOrEmpty(t.Phone) ? "" : " (" + t.Phone + ")"), t.Id.ToString()));

                int editId;
                if (int.TryParse(Request.QueryString["edit"], out editId))
                {
                    var m = _svc.GetById(editId);
                    if (m != null)
                    {
                        if (ddlClass.Items.FindByValue(m.ClassName) != null) ddlClass.SelectedValue = m.ClassName;
                        OpenForm(m);
                    }
                }
                else if (Request.QueryString["add"] == "1")
                {
                    int day, period; int.TryParse(Request.QueryString["day"], out day); int.TryParse(Request.QueryString["period"], out period);
                    OpenForm(new ScheduleModel { ClassName = ddlClass.SelectedValue == "ALL" ? "" : ddlClass.SelectedValue, DayOfWeek = day < 1 ? 1 : day, Period = period < 1 ? 1 : period });
                }
            }
            Reload();
        }

        private void Reload()
        {
            var me = Me;
            string cls = ddlClass.SelectedValue;
            int day; int.TryParse(ddlDay.SelectedValue, out day);

            var list = _svc.GetSchedulesFor(me, cls, day > 0 ? (int?)day : null);
            litScheduleCount.Text = list.Count.ToString();
            gvSchedules.DataSource = list;
            gvSchedules.DataBind();

            pnlWeek.Visible = cls != "ALL";
            if (cls != "ALL")
            {
                litWeekClass.Text = "Lớp " + HttpUtility.HtmlEncode(cls) + (me.IsTeacher ? " (các tiết bạn dạy)" : "");
                litWeek.Text = BuildWeek(_svc.GetSchedulesFor(me, cls, null), cls);
            }
        }

        private string BuildWeek(List<ScheduleModel> lessons, string cls)
        {
            bool mgr = IsManagerView;
            int maxPeriod = Math.Max(5, lessons.Count == 0 ? 5 : lessons.Max(l => l.Period));
            int maxDay = Math.Max(6, lessons.Count == 0 ? 6 : lessons.Max(l => l.DayOfWeek));
            var sb = new StringBuilder();
            sb.Append("<table class='table table-bordered align-middle mb-0 text-center' style='min-width:720px'><thead class='table-light'><tr><th style='width:110px'>Tiết</th>");
            for (int d = 1; d <= maxDay; d++) sb.Append("<th>").Append(ScheduleService.DayName(d)).Append("</th>");
            sb.Append("</tr></thead><tbody>");
            for (int p = 1; p <= maxPeriod; p++)
            {
                sb.Append("<tr><td class='small'><strong>Tiết ").Append(p).Append("</strong><br/><span class='text-muted font-monospace'>")
                  .Append(ScheduleService.PeriodStart(p)).Append(" - ").Append(ScheduleService.PeriodEnd(p)).Append("</span></td>");
                for (int d = 1; d <= maxDay; d++)
                {
                    var l = lessons.FirstOrDefault(x => x.DayOfWeek == d && x.Period == p);
                    if (l == null)
                    {
                        sb.Append("<td class='text-muted small'>");
                        if (mgr) sb.Append("<a class='text-decoration-none' title='Thêm tiết' href='ListSchedule.aspx?add=1&amp;class=").Append(HttpUtility.UrlEncode(cls)).Append("&amp;day=").Append(d).Append("&amp;period=").Append(p).Append("'>+</a>");
                        sb.Append("</td>");
                        continue;
                    }
                    string inner = "<div class='fw-semibold text-dark'>" + HttpUtility.HtmlEncode(l.Subject) + "</div>" +
                                   "<div class='small text-danger'>" + HttpUtility.HtmlEncode(l.Room ?? "") + "</div>" +
                                   "<div class='small text-muted'>" + HttpUtility.HtmlEncode(l.TeacherName ?? "") + "</div>";
                    sb.Append("<td style='background:#FFF7F0'");
                    if (!string.IsNullOrEmpty(l.Note)) sb.Append(" title='").Append(HttpUtility.HtmlAttributeEncode(l.Note)).Append("'");
                    sb.Append(">");
                    if (mgr) sb.Append("<a class='text-decoration-none' href='ListSchedule.aspx?edit=").Append(l.Id).Append("'>").Append(inner).Append("</a>");
                    else sb.Append(inner);
                    sb.Append("</td>");
                }
                sb.Append("</tr>");
            }
            sb.Append("</tbody></table>");
            return sb.ToString();
        }

        protected void FilterChanged(object sender, EventArgs e) { pnlForm.Visible = false; Reload(); }

        // ------------------------------------------------------------------ Manager actions

        private void OpenForm(ScheduleModel m)
        {
            hfId.Value = m.Id > 0 ? m.Id.ToString() : "";
            litFormTitle.Text = m.Id > 0 ? "<i class='fa-solid fa-pen me-2'></i>Sửa tiết học" : "<i class='fa-solid fa-plus me-2'></i>Thêm tiết học";
            txtClass.Text = m.ClassName; txtSubject.Text = m.Subject; txtRoom.Text = m.Room; txtMode.Text = m.Mode;
            txtContent.Text = m.Content; txtPrep.Text = m.Prep; txtNote.Text = m.Note;
            if (ddlFormDay.Items.FindByValue(m.DayOfWeek.ToString()) != null) ddlFormDay.SelectedValue = m.DayOfWeek.ToString();
            if (ddlFormPeriod.Items.FindByValue(m.Period.ToString()) != null) ddlFormPeriod.SelectedValue = m.Period.ToString();
            ddlFormTeacher.SelectedValue = ddlFormTeacher.Items.FindByValue(m.TeacherId.ToString()) != null ? m.TeacherId.ToString() : "0";
            pnlForm.Visible = true;
        }

        protected void btnShowAdd_Click(object sender, EventArgs e)
        {
            if (!IsManagerView) { ShowAlert(false, "Từ chối quyền: chỉ Quản lý mới được thêm tiết học."); return; }
            OpenForm(new ScheduleModel { ClassName = ddlClass.SelectedValue == "ALL" ? "" : ddlClass.SelectedValue, DayOfWeek = 1, Period = 1 });
        }

        protected void btnCancel_Click(object sender, EventArgs e) { pnlForm.Visible = false; }

        protected void btnSave_Click(object sender, EventArgs e)
        {
            if (!IsManagerView) { ShowAlert(false, "Từ chối quyền: chỉ Quản lý mới được sửa thời khóa biểu."); return; }
            int id, teacher;
            int.TryParse(hfId.Value, out id);
            int.TryParse(ddlFormTeacher.SelectedValue, out teacher);
            var m = new ScheduleModel
            {
                Id = id, TeacherId = teacher, ClassName = txtClass.Text, Subject = txtSubject.Text,
                DayOfWeek = int.Parse(ddlFormDay.SelectedValue), Period = int.Parse(ddlFormPeriod.SelectedValue),
                Room = txtRoom.Text, Mode = txtMode.Text, Content = txtContent.Text, Prep = txtPrep.Text, Note = txtNote.Text
            };
            string err = _svc.Save(Me, m);
            if (err != null) { ShowAlert(false, err); return; }   // keep the form open
            pnlForm.Visible = false;
            ShowAlert(true, "Đã lưu tiết học " + m.Subject + " (" + m.ClassName + ", " + ScheduleService.DayName(m.DayOfWeek) + ", tiết " + m.Period + ").");
            if (ddlClass.Items.FindByValue(m.ClassName) == null) ddlClass.Items.Add(new ListItem("Lớp " + m.ClassName, m.ClassName));
            ddlClass.SelectedValue = m.ClassName;
            Reload();
        }

        protected void gvSchedules_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            if (e.CommandName != "editlesson" && e.CommandName != "dellesson") return;
            int id;
            if (!int.TryParse(Convert.ToString(e.CommandArgument), out id)) return;
            if (!IsManagerView) { ShowAlert(false, "Từ chối quyền: chỉ Quản lý mới được sửa thời khóa biểu."); return; }
            if (e.CommandName == "editlesson")
            {
                var m = _svc.GetById(id);
                if (m == null) { ShowAlert(false, "Không tìm thấy tiết học."); Reload(); return; }
                OpenForm(m);
            }
            else
            {
                string err = _svc.Delete(Me, id);
                ShowAlert(err == null, err ?? "Đã xóa tiết học.");
                Reload();
            }
        }

        private void ShowAlert(bool ok, string message)
        {
            pnlStatusAlert.Visible = true;
            pnlStatusAlert.CssClass = ok
                ? "alert alert-success border-start border-4 border-success alert-dismissible fade show mb-4 shadow-sm"
                : "alert alert-danger border-start border-4 border-danger alert-dismissible fade show mb-4 shadow-sm";
            litStatusMessage.Text = (ok ? "<i class='fa-solid fa-circle-check me-2'></i>" : "<i class='fa-solid fa-circle-exclamation me-2'></i>") + HttpUtility.HtmlEncode(message);
        }
    }
}
