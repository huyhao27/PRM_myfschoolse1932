using System;
using System.Net;
using System.Web.Http;
using MyfschoolWeb.Models;
using MyfschoolWeb.Services;

namespace MyfschoolWeb.Controllers.Api
{
    public class RawCsvRequest
    {
        public string CsvData { get; set; }
    }

    /// <summary>CSV import endpoints. Manager only (session or HTTP Basic, see PortalAuthHelper).</summary>
    [RoutePrefix("api/import")]
    public class ImportApiController : ApiController
    {
        private readonly ImportService _importService = new ImportService();

        private IHttpActionResult Run(RawCsvRequest request, Func<UserModel, string, ImportResultModel> action, bool needsCsv)
        {
            try
            {
                var actor = PortalAuthHelper.GetActor(Request);
                if (actor == null) return Content(HttpStatusCode.Unauthorized, new { success = false, message = "Cần đăng nhập." });
                if (!actor.IsManager) return Content(HttpStatusCode.Forbidden, new { success = false, message = "Chỉ Quản lý mới được import dữ liệu." });
                if (needsCsv && (request == null || string.IsNullOrEmpty(request.CsvData))) return BadRequest("Không có dữ liệu CSV để import.");
                return Ok(action(actor, needsCsv ? request.CsvData : null));
            }
            catch (Exception ex) { return InternalServerError(ex); }
        }

        [HttpPost]
        [Route("students")]
        public IHttpActionResult ImportStudents([FromBody] RawCsvRequest request)
        {
            return Run(request, _importService.ImportStudentsFromCsv, true);
        }

        [HttpPost]
        [Route("grades")]
        public IHttpActionResult ImportGrades([FromBody] RawCsvRequest request)
        {
            return Run(request, _importService.ImportGradesFromCsv, true);
        }

        [HttpPost]
        [Route("schedules")]
        public IHttpActionResult ImportSchedules([FromBody] RawCsvRequest request)
        {
            return Run(request, _importService.ImportSchedulesFromCsv, true);
        }

        /// <summary>Re-applies the missing demo rows of backend/sql/seed.sql (never overwrites existing data).</summary>
        [HttpPost]
        [Route("quick-seed")]
        public IHttpActionResult QuickSeed()
        {
            return Run(null, (a, c) => _importService.SeedDemoData(a), false);
        }
    }
}
