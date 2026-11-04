using System;
using System.Net;
using System.Web.Http;
using MyfschoolWeb.Models;
using MyfschoolWeb.Services;

namespace MyfschoolWeb.Controllers.Api
{
    [RoutePrefix("api/schedules")]
    public class SchedulesApiController : ApiController
    {
        private readonly ScheduleService _scheduleService = new ScheduleService();

        private IHttpActionResult Unauthorized401()
        {
            return Content(HttpStatusCode.Unauthorized, new { success = false, message = "Cần đăng nhập (Quản lý hoặc Giáo viên)." });
        }

        // Manager: every lesson. GV: only the lessons he/she teaches. dayOfWeek accepts 1..7, T2..T7, CN.
        [HttpGet]
        [Route("")]
        public IHttpActionResult GetAll(string className = null, string dayOfWeek = null)
        {
            try
            {
                var actor = PortalAuthHelper.GetActor(Request);
                if (actor == null) return Unauthorized401();
                int d = ScheduleService.ParseDay(dayOfWeek);
                var schedules = _scheduleService.GetSchedulesFor(actor, className, d > 0 ? (int?)d : null);
                return Ok(new { success = true, count = schedules.Count, data = schedules });
            }
            catch (Exception ex) { return InternalServerError(ex); }
        }

        [HttpPost]
        [Route("")]
        public IHttpActionResult Create([FromBody] ScheduleModel model)
        {
            return Save(model, 0);
        }

        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Update(int id, [FromBody] ScheduleModel model)
        {
            return Save(model, id);
        }

        private IHttpActionResult Save(ScheduleModel model, int id)
        {
            try
            {
                var actor = PortalAuthHelper.GetActor(Request);
                if (actor == null) return Unauthorized401();
                if (!actor.IsManager) return Content(HttpStatusCode.Forbidden, new { success = false, message = "Chỉ Quản lý mới được sửa thời khóa biểu." });
                if (model == null) return BadRequest("Dữ liệu lịch học không hợp lệ.");
                model.Id = id;
                string err = _scheduleService.Save(actor, model);
                if (err != null) return Content(HttpStatusCode.BadRequest, new { success = false, message = err });
                return Ok(new { success = true, message = "Đã lưu lịch học thành công!", data = _scheduleService.GetById(model.Id) });
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
                if (!actor.IsManager) return Content(HttpStatusCode.Forbidden, new { success = false, message = "Chỉ Quản lý mới được xóa tiết học." });
                string err = _scheduleService.Delete(actor, id);
                if (err != null) return Content(HttpStatusCode.NotFound, new { success = false, message = err });
                return Ok(new { success = true, message = "Đã xóa tiết học." });
            }
            catch (Exception ex) { return InternalServerError(ex); }
        }
    }
}
