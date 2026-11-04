using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Http;
using MyfschoolWeb.Models;
using MyfschoolWeb.Services;

namespace MyfschoolWeb.Controllers.Api
{
    /// <summary>Body for POST/PUT: replaces all scores of studentId + subject + term.</summary>
    public class GradeSaveRequest
    {
        public int StudentId { get; set; }
        public string Subject { get; set; }
        public string Term { get; set; }
        public string Comment { get; set; }
        public List<GradeSaveEntry> Entries { get; set; }
    }

    public class GradeSaveEntry
    {
        public string Type { get; set; }
        public decimal Score { get; set; }
        public DateTime? Date { get; set; }
    }

    /// <summary>
    /// /api/grades : same access rules as the pages. The caller must hold the portal session cookie (Manager or GV).
    /// Manager sees/edits everything; GV sees classes they teach and edits only subjects they teach (Schedule).
    /// </summary>
    [RoutePrefix("api/grades")]
    public class GradesApiController : ApiController
    {
        private readonly GradeService _gradeService = new GradeService();

        private static UserModel CurrentUser()
        {
            try
            {
                var ctx = HttpContext.Current;
                var u = ctx != null && ctx.Session != null ? ctx.Session["CurrentUser"] as UserModel : null;
                return (u != null && (u.IsManager || u.IsTeacher)) ? u : null;
            }
            catch (Exception) { return null; }
        }

        private IHttpActionResult Unauthorized401()
        {
            return Content(System.Net.HttpStatusCode.Unauthorized, new { success = false, message = "Cần đăng nhập bằng tài khoản Quản lý hoặc Giáo viên." });
        }

        private IHttpActionResult Forbidden(string msg)
        {
            return Content(System.Net.HttpStatusCode.Forbidden, new { success = false, message = msg });
        }

        [HttpGet]
        [Route("")]
        public IHttpActionResult GetAll(string className = null, string subject = null, string term = null, string q = null)
        {
            var user = CurrentUser();
            if (user == null) return Unauthorized401();
            try
            {
                if (!string.IsNullOrEmpty(className) && className != "ALL" && !new StudentService().CanAccessClass(user, className))
                    return Forbidden("Bạn không có quyền xem lớp này.");
                var grades = _gradeService.GetGradebook(user, className, subject, term, q);
                return Ok(new { success = true, count = grades.Count, data = grades });
            }
            catch (Exception ex) { return InternalServerError(ex); }
        }

        /// <summary>One student: all subjects of a term, or one subject when ?subject= is given.</summary>
        [HttpGet]
        [Route("{studentId:int}")]
        public IHttpActionResult GetByStudent(int studentId, string subject = null, string term = null)
        {
            var user = CurrentUser();
            if (user == null) return Unauthorized401();
            try
            {
                if (string.IsNullOrWhiteSpace(term)) term = GradeService.DefaultTerm;
                if (!GradeService.IsValidTerm(term)) return BadRequest("Học kỳ không hợp lệ.");
                var student = new StudentService().GetStudentById(studentId);
                if (student == null) return NotFound();
                if (!_gradeService.CanView(user, student.ClassName)) return Forbidden("Bạn không có quyền xem điểm của lớp này.");
                if (!string.IsNullOrWhiteSpace(subject))
                {
                    var g = _gradeService.Get(studentId, subject, term);
                    if (g == null) return NotFound();
                    return Ok(new { success = true, data = g });
                }
                var all = _gradeService.GetGradebook(user, student.ClassName, null, term, studentId.ToString()).Where(x => x.StudentId == studentId).ToList();
                return Ok(new { success = true, count = all.Count, data = all });
            }
            catch (Exception ex) { return InternalServerError(ex); }
        }

        [HttpPost]
        [Route("")]
        public IHttpActionResult Create([FromBody] GradeSaveRequest model)
        {
            return Save(model, null, null, null, true);
        }

        [HttpPut]
        [Route("{studentId:int}")]
        public IHttpActionResult Update(int studentId, string subject, string term, [FromBody] GradeSaveRequest model)
        {
            return Save(model, studentId, subject, term, false);
        }

        private IHttpActionResult Save(GradeSaveRequest model, int? studentId, string subject, string term, bool create)
        {
            var user = CurrentUser();
            if (user == null) return Unauthorized401();
            try
            {
                if (model == null) return BadRequest("Dữ liệu điểm không hợp lệ.");
                if (studentId.HasValue) model.StudentId = studentId.Value;
                if (!string.IsNullOrWhiteSpace(subject)) model.Subject = subject;
                if (!string.IsNullOrWhiteSpace(term)) model.Term = term;
                if (string.IsNullOrWhiteSpace(model.Term)) model.Term = GradeService.DefaultTerm;
                if (model.StudentId <= 0 || string.IsNullOrWhiteSpace(model.Subject)) return BadRequest("Thiếu mã học sinh hoặc môn học.");
                if (model.Entries == null || model.Entries.Count == 0) return BadRequest("Cần ít nhất một đầu điểm.");

                bool exists = _gradeService.Get(model.StudentId, model.Subject, model.Term) != null;
                if (create && exists) return Content(System.Net.HttpStatusCode.Conflict, new { success = false, message = "Đã có điểm môn này trong học kỳ, hãy dùng PUT để cập nhật." });
                if (!create && !exists) return NotFound();

                var entries = model.Entries.Select(x => new GradeEntry { Type = x.Type, Score = x.Score, Date = x.Date }).ToList();
                string err = _gradeService.Save(user, model.StudentId, model.Subject, model.Term, entries, model.Comment);
                if (err != null)
                    return err.StartsWith("Bạn") ? Forbidden(err) : (IHttpActionResult)BadRequest(err);
                var saved = _gradeService.Get(model.StudentId, model.Subject.Trim(), model.Term);
                return Ok(new { success = true, message = create ? "Đã thêm điểm." : "Đã cập nhật điểm.", data = saved });
            }
            catch (Exception ex) { return InternalServerError(ex); }
        }

        [HttpDelete]
        [Route("{studentId:int}")]
        public IHttpActionResult Delete(int studentId, string subject, string term = null)
        {
            var user = CurrentUser();
            if (user == null) return Unauthorized401();
            try
            {
                if (string.IsNullOrWhiteSpace(term)) term = GradeService.DefaultTerm;
                if (string.IsNullOrWhiteSpace(subject)) return BadRequest("Thiếu môn học.");
                if (_gradeService.Get(studentId, subject, term) == null) return NotFound();
                string err = _gradeService.Delete(user, studentId, subject, term);
                if (err != null) return Forbidden(err);
                return Ok(new { success = true, message = "Đã xóa bảng điểm." });
            }
            catch (Exception ex) { return InternalServerError(ex); }
        }
    }
}
