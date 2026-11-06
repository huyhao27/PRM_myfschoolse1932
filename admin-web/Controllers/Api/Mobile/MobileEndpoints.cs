using System;
using System.Linq;
using System.Net.Http;
using System.Web.Http;
using MyfschoolWeb.Services;
using Newtonsoft.Json.Linq;

namespace MyfschoolWeb.Controllers.Api.Mobile
{
    /// <summary>GET /api/m/health, POST /api/m/login, POST /api/m/reset-password, GET /api/m/me.</summary>
    [RoutePrefix("api/m")]
    public partial class MobileController : MobileApiController
    {
        [HttpGet, Route("health")]
        public HttpResponseMessage Health()
        {
            return Run(() => Json(200, new { status = "ok" }));
        }

        [HttpPost, Route("login")]
        public HttpResponseMessage Login()
        {
            return Run(() =>
            {
                JObject b = ReadBody();
                string identifier = BodyString(b, "identifier"), password = BodyString(b, "password");
                if (identifier == null || password == null || identifier.Trim() == "" || password == "")
                    return Error(400, "identifier and password are required");
                string id = MobileService.NormalizeIdentifier(identifier);
                string key = (id.Length > 200 ? id.Substring(0, 200) : id) + "|" + ClientIp();

                int wait = MobileLimits.Login.RetryAfter(key);
                if (wait > 0) return TooManyRequests(wait);

                MobileUser user = Svc.Authenticate(id, password);
                if (user == null)
                {
                    MobileLimits.Login.Hit(key);
                    return Error(401, "Invalid credentials");
                }
                MobileLimits.Login.Clear(key);   // 5 consecutive failures lock the pair; a success resets the counter
                return Json(200, new { token = MobileJwt.Create(user.Id, user.Role), user = MobileService.PublicUser(user) });
            });
        }

        [HttpPost, Route("reset-password")]
        public HttpResponseMessage ResetPassword()
        {
            return Run(() =>
            {
                JObject b = ReadBody();
                string identifier = BodyString(b, "identifier"), newPassword = BodyString(b, "newPassword");
                if (identifier == null || identifier.Trim() == "") return Error(400, "identifier is required");
                if (newPassword == null || newPassword.Length < 6) return Error(400, "newPassword must be at least 6 characters");
                if (newPassword.Length > MobileService.MaxNewPassword)
                    return Error(400, "newPassword must be at most " + MobileService.MaxNewPassword + " characters");
                string id = MobileService.NormalizeIdentifier(identifier);
                string key = (id.Length > 200 ? id.Substring(0, 200) : id) + "|" + ClientIp();

                int wait = MobileLimits.Reset.TryAcquire(key);
                if (wait > 0) return TooManyRequests(wait);

                if (!Svc.ResetPassword(id, newPassword)) return Error(404, "User not found");
                return Json(200, new { message = "Password updated" });
            });
        }

        [HttpGet, Route("me")]
        public HttpResponseMessage Me()
        {
            return Run(() =>
            {
                MobileUser user = Svc.FindProfile(RequireAuth());
                if (user == null) return Error(401, "Invalid token");
                return Json(200, MobileService.PublicUser(user));
            });
        }
    }

    /// <summary>GET /api/m/children, /schedule, /schedule/{id}, /grades, /grades/{subject} (read-only).</summary>
    public partial class MobileController : MobileApiController
    {
        [HttpGet, Route("children")]
        public HttpResponseMessage Children()
        {
            return Run(() => Json(200, Svc.VisibleStudents(Guard()).Select(MobileService.StudentJson).ToList()));
        }

        [HttpGet, Route("schedule")]
        public HttpResponseMessage Schedule()
        {
            return Run(() =>
            {
                MobileUser user = Guard();
                return Json(200, Svc.ScheduleList(user, Query("studentId"), Query("className")));
            });
        }

        [HttpGet, Route("schedule/{id}")]
        public HttpResponseMessage ScheduleDetail(string id)
        {
            return Run(() =>
            {
                MobileUser user = Guard();
                int lessonId = MobileService.ParseId(id, "id");
                return Json(200, Svc.ScheduleDetail(user, lessonId, Query("studentId")));
            });
        }

        [HttpGet, Route("grades")]
        public HttpResponseMessage Grades()
        {
            return Run(() =>
            {
                MobileUser user = Guard();
                return Json(200, Svc.GradeSummary(user, Query("studentId"), Query("term")));
            });
        }

        [HttpGet, Route("grades/{subject}")]
        public HttpResponseMessage GradeDetail(string subject)
        {
            return Run(() =>
            {
                MobileUser user = Guard();
                return Json(200, Svc.GradeDetail(user, Query("studentId"), Query("term"), subject));
            });
        }
    }

    /// <summary>GET/POST /api/m/requests, GET /requests/{id}, POST /requests/{id}/decision.</summary>
    public partial class MobileController : MobileApiController
    {
        private static readonly string[] Types = { "Xin nghỉ học", "Xin phép đi trễ", "Xin đổi chỗ ngồi" };

        [HttpGet, Route("requests")]
        public HttpResponseMessage ListRequests()
        {
            return Run(() =>
            {
                MobileUser user = Guard();
                string status = Query("status");
                if (status != null && Array.IndexOf(MobileService.Statuses, status) < 0) return Error(400, "Invalid status filter");
                return Json(200, Svc.RequestList(user, status));
            });
        }

        [HttpGet, Route("requests/{id}")]
        public HttpResponseMessage RequestDetail(string id)
        {
            return Run(() =>
            {
                MobileUser user = Guard();
                return Json(200, Svc.RequestDetail(user, MobileService.ParseId(id, "id")));
            });
        }

        /// <summary>JS Number.isInteger on a parsed JSON value.</summary>
        private static long? IntegerOf(JToken t)
        {
            if (t == null) return null;
            if (t.Type == JTokenType.Integer) { try { return (long)t; } catch (OverflowException) { return long.MaxValue; } }
            if (t.Type == JTokenType.Float)
            {
                double d = (double)t;
                if (d == Math.Floor(d) && Math.Abs(d) < 9007199254740992d) return (long)d;
            }
            return null;
        }

        // HS (for themselves) and PH (for a linked child) create requests.
        [HttpPost, Route("requests")]
        public HttpResponseMessage CreateRequest()
        {
            return Run(() =>
            {
                JObject b = ReadBody();
                MobileUser user = Guard("HS", "PH");
                long? studentId = IntegerOf(b["studentId"]);
                if (!(studentId.HasValue && studentId.Value > 0)) return Error(400, "studentId is required");
                string type = BodyString(b, "type");
                if (type == null || Array.IndexOf(Types, type) < 0) return Error(400, "Invalid request type");
                string reason = (BodyString(b, "reason") ?? "").Trim();
                if (reason.Length == 0) return Error(400, "reason is required");
                if (reason.Length > MobileService.MaxText) return Error(400, "reason must be at most " + MobileService.MaxText + " characters");
                string fromDate = MobileService.ParseDate(BodyString(b, "fromDate"));
                if (fromDate == null) return Error(400, "fromDate must be a date (YYYY-MM-DD)");
                string toDate = fromDate;
                JToken to = b["toDate"];
                if (to != null && to.Type != JTokenType.Null && !(to.Type == JTokenType.String && (string)to == ""))
                {
                    toDate = MobileService.ParseDate(to.Type == JTokenType.String ? (string)to : null);
                    if (toDate == null) return Error(400, "toDate must be a date (YYYY-MM-DD)");
                    if (string.CompareOrdinal(toDate, fromDate) < 0) return Error(400, "toDate must not be before fromDate");
                }
                if (studentId.Value > int.MaxValue || !Svc.StudentVisible(user, studentId.Value))
                    return Error(403, "You cannot create a request for this student");
                return Json(201, Svc.CreateRequest(user, (int)studentId.Value, type, fromDate, toDate, reason));
            });
        }

        // GV/Manager approve or reject a pending request they can see.
        [HttpPost, Route("requests/{id}/decision")]
        public HttpResponseMessage DecideRequestAction(string id)
        {
            return Run(() =>
            {
                JObject b = ReadBody();
                MobileUser user = Guard("GV", "Manager");
                int requestId = MobileService.ParseId(id, "id");
                string decision = BodyString(b, "decision");
                if (decision != "approved" && decision != "rejected") return Error(400, "decision must be \"approved\" or \"rejected\"");
                string comment = null;
                JToken c = b["comment"];
                if (c != null && c.Type != JTokenType.Null)
                {
                    if (c.Type != JTokenType.String) return Error(400, "comment must be text");
                    comment = ((string)c).Trim();
                    if (comment.Length == 0) comment = null;
                    if (comment != null && comment.Length > MobileService.MaxText)
                        return Error(400, "comment must be at most " + MobileService.MaxText + " characters");
                }
                return Json(200, Svc.DecideRequest(user, requestId, decision, comment));
            });
        }
    }

    /// <summary>GET /api/m/clubs, /clubs/{id}, POST /clubs/{id}/join.</summary>
    public partial class MobileController : MobileApiController
    {
        [HttpGet, Route("clubs")]
        public HttpResponseMessage ListClubs()
        {
            return Run(() =>
            {
                MobileUser user = Guard();
                string[] qv = System.Web.HttpContext.Current.Request.QueryString.GetValues("q");
                // Node: only a single string is used, trimmed and cut to 50 characters
                string q = qv != null && qv.Length == 1 ? qv[0].Trim() : "";
                if (q.Length > 50) q = q.Substring(0, 50);
                return Json(200, Svc.ClubList(user.Id, q));
            });
        }

        [HttpGet, Route("clubs/{id}")]
        public HttpResponseMessage ClubDetail(string id)
        {
            return Run(() =>
            {
                MobileUser user = Guard();
                return Json(200, Svc.ClubDetail(user.Id, MobileService.ParseId(id, "id")));
            });
        }

        // Students ask to join; the membership starts as "pending".
        [HttpPost, Route("clubs/{id}/join")]
        public HttpResponseMessage JoinClub(string id)
        {
            return Run(() =>
            {
                ReadBody();
                MobileUser user = Guard("HS");
                Svc.ClubJoin(user.Id, MobileService.ParseId(id, "id"));
                return Json(201, new { status = "pending" });
            });
        }
    }

    /// <summary>Everything else under /api/m -> 404 {"message":"Not found"} (after the body parser, like Express).</summary>
    public partial class MobileController : MobileApiController
    {
        [AcceptVerbs("GET", "POST", "PUT", "PATCH", "DELETE", "HEAD")]
        [Route("{*path}")]
        public HttpResponseMessage NotFoundAny(string path = null)
        {
            return Run(() =>
            {
                if (Request.Method == HttpMethod.Post || Request.Method == HttpMethod.Put || Request.Method.Method == "PATCH") ReadBody();
                return Error(404, "Not found");
            });
        }
    }
}
