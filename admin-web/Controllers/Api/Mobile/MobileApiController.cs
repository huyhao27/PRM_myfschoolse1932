using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;
using System.Web.Http;
using MyfschoolWeb.Services;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Newtonsoft.Json.Serialization;

namespace MyfschoolWeb.Controllers.Api.Mobile
{
    /// <summary>JSON settings of the mobile API: camelCase, nulls kept, compact, invariant culture (same bytes as Express res.json).</summary>
    public static class MobileJson
    {
        public static readonly JsonSerializerSettings Settings = new JsonSerializerSettings
        {
            ContractResolver = new CamelCasePropertyNamesContractResolver(),
            NullValueHandling = NullValueHandling.Include,
            Formatting = Formatting.None,
            Culture = CultureInfo.InvariantCulture,
            DateParseHandling = DateParseHandling.None
        };
    }

    /// <summary>Shared limiters (in memory, per process).</summary>
    public static class MobileLimits
    {
        public static readonly MobileRateLimiter Login = MobileRateLimiter.FromConfig();
        public static readonly MobileRateLimiter Reset = MobileRateLimiter.FromConfig();
    }

    /// <summary>
    /// Base of every /api/m controller: stateless bearer-token auth (role re-read from the DB), body parsing and a uniform
    /// error contract: {"message": "..."} with the status of the Node API; unexpected errors -> 500 without details.
    /// </summary>
    public abstract class MobileApiController : ApiController
    {
        public const int MaxBodyBytes = 100 * 1024;   // express.json({ limit: '100kb' })
        protected static readonly MobileService Svc = new MobileService();
        private static readonly Regex BearerRx = new Regex(@"^Bearer\s+(\S+)\z", RegexOptions.IgnoreCase | RegexOptions.Compiled);

        protected HttpResponseMessage Run(Func<HttpResponseMessage> action)
        {
            try { return action(); }
            catch (MobileHttpException e) { return Json(e.Status, new { message = e.Message }); }
            catch (Exception e)
            {
                try
                {
                    string line = "[mobile-api] unhandled " + e.GetType().Name + ": " + e.Message;
                    System.Diagnostics.Trace.TraceError(line);
                    Console.Error.WriteLine(line);
                }
                catch (Exception) { }
                return Json(500, new { message = "Internal server error" });
            }
        }

        protected HttpResponseMessage Json(int status, object body)
        {
            var res = new HttpResponseMessage((HttpStatusCode)status);
            res.Content = new StringContent(JsonConvert.SerializeObject(body, MobileJson.Settings), new UTF8Encoding(false), "application/json");
            return res;
        }

        protected HttpResponseMessage Error(int status, string message) { return Json(status, new { message = message }); }

        protected HttpResponseMessage TooManyRequests(int retryAfterSeconds)
        {
            var res = Error(429, "Too many attempts. Try again later.");
            res.Headers.RetryAfter = new RetryConditionHeaderValue(TimeSpan.FromSeconds(retryAfterSeconds));
            return res;
        }

        // ---------------------------------------------------------------- request helpers

        /// <summary>Request body as a JSON object ({} when empty or not an object). 413 above 100 KB, 400 "Malformed JSON".</summary>
        protected JObject ReadBody()
        {
            HttpRequest req = HttpContext.Current.Request;
            if (req.ContentLength > MaxBodyBytes) throw new MobileHttpException(413, "Payload too large");
            byte[] data;
            using (var ms = new MemoryStream())
            {
                var buf = new byte[8192];
                int n;
                Stream s = req.InputStream;
                while ((n = s.Read(buf, 0, buf.Length)) > 0)
                {
                    ms.Write(buf, 0, n);
                    if (ms.Length > MaxBodyBytes) throw new MobileHttpException(413, "Payload too large");
                }
                data = ms.ToArray();
            }
            string text = Encoding.UTF8.GetString(data);
            if (text.Trim().Length == 0) return new JObject();
            try
            {
                using (var sr = new StringReader(text))
                using (var jr = new JsonTextReader(sr) { DateParseHandling = DateParseHandling.None, FloatParseHandling = FloatParseHandling.Double })
                {
                    JToken t = JToken.Load(jr);
                    if (jr.Read()) throw new JsonException("trailing content");
                    if (t.Type != JTokenType.Object && t.Type != JTokenType.Array) throw new JsonException("not an object");
                    return t as JObject ?? new JObject();
                }
            }
            catch (JsonException) { throw new MobileHttpException(400, "Malformed JSON"); }
        }

        /// <summary>The string value of a body property, or null when absent / not a JSON string.</summary>
        protected static string BodyString(JObject b, string key)
        {
            JToken t;
            return b.TryGetValue(key, out t) && t.Type == JTokenType.String ? (string)t : null;
        }

        /// <summary>Query value: null when absent; repeated parameters are joined with ',' (like String(array) in JS).</summary>
        protected static string Query(string key)
        {
            string[] v = HttpContext.Current.Request.QueryString.GetValues(key);
            return v == null ? null : string.Join(",", v);
        }

        protected static string ClientIp()
        {
            // The socket address only: X-Forwarded-For is client-controlled and would let an attacker dodge the limiter.
            return HttpContext.Current.Request.UserHostAddress ?? "unknown";
        }

        // ---------------------------------------------------------------- auth

        /// <summary>requireAuth: Bearer header + token check. Returns the user id of the token.</summary>
        protected static int RequireAuth()
        {
            string h = HttpContext.Current.Request.Headers["Authorization"] ?? "";
            Match m = BearerRx.Match(h);
            if (!m.Success) throw new MobileHttpException(401, "Missing or malformed Authorization header");
            int sub;
            switch (MobileJwt.Verify(m.Groups[1].Value, out sub))
            {
                case JwtStatus.Ok: return sub;
                case JwtStatus.Expired: throw new MobileHttpException(401, "Token expired");
                default: throw new MobileHttpException(401, "Invalid token");
            }
        }

        /// <summary>requireAuth + loadUser (+ requireRole). The role comes from the database, never from the token.</summary>
        protected MobileUser Guard(params string[] roles)
        {
            int sub = RequireAuth();
            MobileUser user = Svc.FindProfile(sub);
            if (user == null) throw new MobileHttpException(401, "Invalid token");
            if (roles.Length > 0 && Array.IndexOf(roles, user.Role) < 0) throw new MobileHttpException(403, "Forbidden for your role");
            return user;
        }
    }
}
