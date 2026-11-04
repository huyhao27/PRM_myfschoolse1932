using System;
using System.Text;
using System.Web;
using System.Web.Http;
using MyfschoolWeb.Models;
using MyfschoolWeb.Services;

namespace MyfschoolWeb.Controllers.Api
{
    /// <summary>
    /// Who is calling an /api endpoint of the portal: the web session (Session["CurrentUser"], when the pipeline exposes it)
    /// or HTTP Basic credentials "phone-or-email:password" checked with StudentService.TryLogin. Only Manager and GV pass.
    /// </summary>
    public static class PortalAuthHelper
    {
        public static UserModel GetActor(System.Net.Http.HttpRequestMessage request)
        {
            try
            {
                var ctx = HttpContext.Current;
                var su = (ctx != null && ctx.Session != null) ? ctx.Session["CurrentUser"] as UserModel : null;
                if (su != null) return su;
            }
            catch (Exception) { }
            try
            {
                var h = request.Headers.Authorization;
                if (h != null && string.Equals(h.Scheme, "Basic", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrEmpty(h.Parameter))
                {
                    string raw = Encoding.UTF8.GetString(Convert.FromBase64String(h.Parameter));
                    int i = raw.IndexOf(':');
                    if (i > 0) return new StudentService().TryLogin(raw.Substring(0, i), raw.Substring(i + 1)).User;
                }
            }
            catch (Exception) { }
            return null;
        }
    }

    public class StudentRequest
    {
        public string Name { get; set; }
        public string Email { get; set; }
        public string Phone { get; set; }
        public string ClassName { get; set; }
        /// <summary>HS (default), GV, PH.</summary>
        public string Role { get; set; }
        /// <summary>Optional, default 123456.</summary>
        public string Password { get; set; }
    }

    [RoutePrefix("api/students")]
    public class StudentsApiController : ApiController
    {
        private readonly StudentService _studentService = new StudentService();

        private IHttpActionResult Unauthorized401()
        {
            return Content(System.Net.HttpStatusCode.Unauthorized, new { success = false, message = "Cần đăng nhập (Quản lý hoặc Giáo viên)." });
        }

        // Manager: all students; GV: only students of the classes he/she teaches.
        [HttpGet]
        [Route("")]
        public IHttpActionResult GetAll(string className = null, string q = null)
        {
            try
            {
                var actor = PortalAuthHelper.GetActor(Request);
                if (actor == null) return Unauthorized401();
                var students = _studentService.GetStudentsFor(actor, className, q);
                return Ok(new { success = true, count = students.Count, data = students });
            }
            catch (Exception ex) { return InternalServerError(ex); }
        }

        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult GetById(int id)
        {
            try
            {
                var actor = PortalAuthHelper.GetActor(Request);
                if (actor == null) return Unauthorized401();
                var student = _studentService.GetStudentById(id);
                if (student == null || (!actor.IsManager && !_studentService.CanAccessClass(actor, student.ClassName))) return NotFound();
                return Ok(new { success = true, data = student, parents = _studentService.GetParentsOf(id) });
            }
            catch (Exception ex) { return InternalServerError(ex); }
        }

        // Manager only.
        [HttpPost]
        [Route("")]
        public IHttpActionResult Create([FromBody] StudentRequest model)
        {
            try
            {
                var actor = PortalAuthHelper.GetActor(Request);
                if (actor == null) return Unauthorized401();
                if (!actor.IsManager) return Content(System.Net.HttpStatusCode.Forbidden, new { success = false, message = "Chỉ Quản lý mới được tạo tài khoản." });
                if (model == null) return BadRequest("Dữ liệu không hợp lệ.");
                var r = _studentService.CreateUser(new UserModel { Name = model.Name, Email = model.Email, Phone = model.Phone, ClassName = model.ClassName, Role = model.Role ?? Roles.Student }, actor.Role, model.Password);
                if (!r.Success) return Content(System.Net.HttpStatusCode.BadRequest, new { success = false, message = r.Message });
                return Ok(new { success = true, message = r.Message, data = r.User });
            }
            catch (Exception ex) { return InternalServerError(ex); }
        }

        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Update(int id, [FromBody] StudentRequest model)
        {
            try
            {
                var actor = PortalAuthHelper.GetActor(Request);
                if (actor == null) return Unauthorized401();
                if (!actor.IsManager) return Content(System.Net.HttpStatusCode.Forbidden, new { success = false, message = "Chỉ Quản lý mới được sửa tài khoản." });
                if (model == null) return BadRequest("Dữ liệu không hợp lệ.");
                var r = _studentService.UpdateUserChecked(actor, new UserModel { Id = id, Name = model.Name, Email = model.Email, Phone = model.Phone, ClassName = model.ClassName });
                if (!r.Success) return Content(System.Net.HttpStatusCode.BadRequest, new { success = false, message = r.Message });
                return Ok(new { success = true, message = r.Message, data = r.User });
            }
            catch (Exception ex) { return InternalServerError(ex); }
        }

        [HttpDelete]
        [Route("{id:int}")]
        public IHttpActionResult Delete(int id)
        {
            try
            {
                var actor = PortalAuthHelper.GetActor(Request);
                if (actor == null) return Unauthorized401();
                if (!actor.IsManager) return Content(System.Net.HttpStatusCode.Forbidden, new { success = false, message = "Chỉ Quản lý mới được xóa tài khoản." });
                var r = _studentService.DeleteUserSafe(actor, id);
                if (!r.Success) return Content(System.Net.HttpStatusCode.BadRequest, new { success = false, message = r.Message });
                return Ok(new { success = true, message = r.Message });
            }
            catch (Exception ex) { return InternalServerError(ex); }
        }
    }
}
