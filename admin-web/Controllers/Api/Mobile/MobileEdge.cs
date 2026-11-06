using System;
using System.Configuration;
using System.Linq;
using System.Web;

namespace MyfschoolWeb.Controllers.Api.Mobile
{
    /// <summary>
    /// Request-edge rules of /api/m: CORS allow-list (appSettings AllowedOrigins, never "*"), preflight, security headers.
    /// Native Android/iOS clients send no Origin header and need no CORS at all.
    /// </summary>
    public static class MobileEdge
    {
        public const string DefaultAllowedOrigins = "http://localhost:8090,http://localhost:8091,http://localhost:5555";

        public static bool IsMobilePath(string path)
        {
            if (path == null) return false;
            return path.Equals("/api/m", StringComparison.OrdinalIgnoreCase) || path.StartsWith("/api/m/", StringComparison.OrdinalIgnoreCase);
        }

        public static bool IsMobileAppRelativePath(string appRelative)
        {
            if (appRelative == null) return false;
            return appRelative.Equals("~/api/m", StringComparison.OrdinalIgnoreCase) || appRelative.StartsWith("~/api/m/", StringComparison.OrdinalIgnoreCase);
        }

        private static string[] AllowedOrigins()
        {
            string raw = ConfigurationManager.AppSettings["AllowedOrigins"];
            if (string.IsNullOrWhiteSpace(raw)) raw = DefaultAllowedOrigins;
            return raw.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries).Select(s => s.Trim().TrimEnd('/')).Where(s => s.Length > 0 && s != "*").ToArray();
        }

        /// <summary>Called from Application_BeginRequest. Returns true when the request was fully answered (preflight).</summary>
        public static bool Begin(HttpContext ctx)
        {
            HttpResponse res = ctx.Response;
            HttpRequest req = ctx.Request;
            res.AppendHeader("X-Content-Type-Options", "nosniff");
            res.Cache.SetCacheability(HttpCacheability.NoCache);
            res.Cache.SetNoStore();

            string origin = req.Headers["Origin"];
            bool allowed = !string.IsNullOrEmpty(origin) && AllowedOrigins().Contains(origin, StringComparer.Ordinal);
            bool preflight = req.HttpMethod == "OPTIONS";
            if (!string.IsNullOrEmpty(origin)) res.AppendHeader("Vary", "Origin");

            if (allowed)
            {
                res.AppendHeader("Access-Control-Allow-Origin", origin);   // the exact origin, never "*"
                if (preflight)
                {
                    res.AppendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
                    res.AppendHeader("Access-Control-Allow-Headers", "Authorization, Content-Type");
                    res.AppendHeader("Access-Control-Max-Age", "600");
                }
            }
            if (!preflight) return false;

            // Disallowed origin: no CORS headers at all, so the browser blocks the real request.
            res.StatusCode = (!string.IsNullOrEmpty(origin) && !allowed) ? 403 : 204;
            res.SuppressContent = true;
            ctx.ApplicationInstance.CompleteRequest();
            return true;
        }
    }
}
