using System;
using System.Data;
using System.Linq;
using System.Web.UI;
using MyfschoolWeb.DataAccess;
using MyfschoolWeb.Models;
using MyfschoolWeb.Services;

namespace MyfschoolWeb
{
    public partial class Default : Page
    {
        private readonly StudentService _studentService = new StudentService();

        // Presentation helpers used by Default.aspx (no data logic).
        protected int PendingRequestsCount;
        protected int PendingClubsCount;
        protected string GreetingName
        {
            get
            {
                var u = Session["CurrentUser"] as UserModel;
                return u == null ? "" : (string.IsNullOrEmpty(u.Name) ? u.Email : u.Name);
            }
        }

        /// <summary>Status badge (icon + label) for an evaluation level.</summary>
        protected static string LevelBadge(object level)
        {
            string l = Convert.ToString(level) ?? "";
            string cls = "is-info", icon = "fa-circle-info";
            if (l == "Tốt") { cls = "is-approved"; icon = "fa-circle-check"; }
            else if (l == "Đạt") { cls = "is-pending"; icon = "fa-circle-half-stroke"; }
            else if (l == "Chưa đạt") { cls = "is-rejected"; icon = "fa-circle-xmark"; }
            return "<span class=\"status-badge " + cls + "\"><i class=\"fa-solid " + icon + "\" aria-hidden=\"true\"></i>" + System.Web.HttpUtility.HtmlEncode(l) + "</span>";
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            var currentUser = Session["CurrentUser"] as UserModel;
            if (currentUser == null)
            {
                Response.Redirect("Login.aspx");
                return;
            }

            if (!IsPostBack)
            {
                if (currentUser.IsManager)
                {
                    pnlAdminBanner.Visible = true;
                    pnlTeacherBanner.Visible = false;
                    litDashboardSubtitle.Text = "Hệ thống quản lý toàn trường THPT FPT Hà Nội - dành cho Quản lý";
                    litStudentCardSubtitle.Text = "TỔNG HỌC SINH TOÀN TRƯỜNG";
                    litClassCardSubtitle.Text = "SỐ LỚP TOÀN TRƯỜNG";
                    litStudentQuickTitle.Text = "Hồ Sơ Học Sinh Toàn Trường";
                    litStudentQuickDesc.Text = "Quản lý danh sách học sinh các lớp khối 10, 11, 12";
                }
                else
                {
                    pnlAdminBanner.Visible = false;
                    pnlTeacherBanner.Visible = true;
                    litTeacherName.Text = Server.HtmlEncode(currentUser.Name ?? "Giáo viên");
                    litDashboardSubtitle.Text = "Hệ thống quản lý học tập & sổ điểm THPT FPT Hà Nội";
                    litStudentCardSubtitle.Text = "SĨ SỐ CÁC LỚP PHỤ TRÁCH";
                    litClassCardSubtitle.Text = "SỐ LỚP ĐANG DẠY";
                    litStudentQuickTitle.Text = "Danh Sách Học Sinh";
                    litStudentQuickDesc.Text = "Quản lý hồ sơ học sinh các lớp bạn dạy";
                }

                try
                {
                    PendingRequestsCount = new RequestService().CountPending(currentUser);
                    PendingClubsCount = new ClubService().CountPendingJoins();
                    litPendingRequests.Text = PendingRequestsCount.ToString();
                    litPendingClubs.Text = PendingClubsCount.ToString();
                }
                catch (Exception ex)
                {
                    litPendingRequests.Text = "0";
                    litPendingClubs.Text = "0";
                    System.Diagnostics.Trace.TraceError("Dashboard pending counts: " + ex);
                }

                LoadDashboardStats(currentUser);
            }
        }

        // NOTE: minimal SQL-based dashboard (counts + 8 latest grades). Page-migration agent may refine.
        private void LoadDashboardStats(UserModel user)
        {
            try
            {
                var classes = _studentService.GetAccessibleClasses(user);
                var students = _studentService.GetStudentsFor(user);
                litTotalStudents.Text = students.Count.ToString();
                litTotalClasses.Text = classes.Count.ToString();

                var ids = students.Select(s => s.Id).ToList();
                if (ids.Count == 0)
                {
                    litTotalGrades.Text = "0";
                    litPassingRate.Text = "100%";
                    gvRecentGrades.DataSource = new object[0];   // shows the empty state
                    gvRecentGrades.DataBind();
                    return;
                }
                string idList = string.Join(",", ids);   // ints only, safe to inline

                litTotalGrades.Text = SqlDb.Scalar<int>("SELECT COUNT(*) FROM dbo.Grade WHERE studentId IN (" + idList + ")").ToString();

                // Evaluation = average of each (student, subject), TT22-like bands on 0-10 scale.
                var avgs = SqlDb.Query("SELECT AVG(CAST(score AS FLOAT)) FROM dbo.Grade WHERE studentId IN (" + idList + ") GROUP BY studentId, subject",
                                       r => r.GetDouble(0));
                int tot = avgs.Count(a => a >= 8), kha = avgs.Count(a => a >= 6.5 && a < 8), dat = avgs.Count(a => a >= 5 && a < 6.5), chuaDat = avgs.Count(a => a < 5);
                int totalEvaluated = tot + kha + dat + chuaDat;
                litTotCount.Text = tot.ToString();
                litKhaCount.Text = kha.ToString();
                litDatCount.Text = dat.ToString();
                litChuaDatCount.Text = chuaDat.ToString();

                if (totalEvaluated > 0)
                {
                    int totPct = (int)Math.Round((double)tot / totalEvaluated * 100);
                    int khaPct = (int)Math.Round((double)kha / totalEvaluated * 100);
                    int datPct = (int)Math.Round((double)dat / totalEvaluated * 100);
                    int chuaDatPct = (int)Math.Round((double)chuaDat / totalEvaluated * 100);
                    litTotPercent.Text = totPct.ToString();
                    litKhaPercent.Text = khaPct.ToString();
                    litDatPercent.Text = datPct.ToString();
                    litChuaDatPercent.Text = chuaDatPct.ToString();
                    pnlTotBar.Style["width"] = totPct + "%";
                    pnlKhaBar.Style["width"] = khaPct + "%";
                    pnlDatBar.Style["width"] = datPct + "%";
                    pnlChuaDatBar.Style["width"] = chuaDatPct + "%";
                    litPassingRate.Text = (int)Math.Round((double)(tot + kha + dat) / totalEvaluated * 100) + "%";
                }
                else
                {
                    litPassingRate.Text = "100%";
                }

                // 8 latest grade rows shaped like the old GridView columns.
                var raw = SqlDb.Query(
                    @"SELECT TOP 8 g.id, s.className, s.id AS sid, s.name, g.subject, g.score
                      FROM dbo.Grade g JOIN dbo.Users s ON s.id = g.studentId
                      WHERE g.studentId IN (" + idList + ") ORDER BY g.createdAt DESC, g.id DESC");
                var dt = new DataTable();
                foreach (var c in new[] { "Id", "ClassName", "StudentId", "StudentName", "SubjectName", "Tx1Score", "GkScore", "CkScore", "DtbMhk", "BadgeClass", "EvaluationLevel" })
                    dt.Columns.Add(c);
                foreach (DataRow r in raw.Rows)
                {
                    double sc = Convert.ToDouble(r["score"]);
                    string level = sc >= 8 ? "Tốt" : sc >= 6.5 ? "Khá" : sc >= 5 ? "Đạt" : "Chưa đạt";
                    string badge = sc >= 8 ? "badge bg-success" : sc >= 6.5 ? "badge bg-primary" : sc >= 5 ? "badge bg-info text-dark" : "badge bg-danger";
                    dt.Rows.Add(r["id"], r["className"], r["sid"], r["name"], r["subject"], sc.ToString("0.##"), "", "", sc.ToString("0.##"), badge, level);
                }
                gvRecentGrades.DataSource = dt;
                gvRecentGrades.DataBind();
            }
            catch (Exception ex)
            {
                litTotalStudents.Text = "0";
                litTotalClasses.Text = "0";
                litTotalGrades.Text = "0";
                System.Diagnostics.Trace.TraceError("Dashboard: " + ex);
            }
        }
    }
}
