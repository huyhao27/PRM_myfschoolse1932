using System;
using System.Web;
using System.Web.SessionState;

[assembly: PreApplicationStartMethod(typeof(MyfschoolWeb.Controllers.Api.ApiSessionModule), "Register")]

namespace MyfschoolWeb.Controllers.Api
{
    /// <summary>
    /// Web API requests do not get ASP.NET session state by default. This module turns it on for /api/* so that the
    /// API controllers can read Session["CurrentUser"] (the portal login) and apply the same access rules as the pages.
    /// </summary>
    public class ApiSessionModule : IHttpModule
    {
        public static void Register()
        {
            HttpApplication.RegisterModule(typeof(ApiSessionModule));
        }

        public void Init(HttpApplication app)
        {
            app.PostAuthenticateRequest += (s, e) =>
            {
                var ctx = ((HttpApplication)s).Context;
                string path = ctx.Request.AppRelativeCurrentExecutionFilePath ?? "";
                if (path.StartsWith("~/api/", StringComparison.OrdinalIgnoreCase))
                    ctx.SetSessionStateBehavior(SessionStateBehavior.Required);
            };
        }

        public void Dispose() { }
    }
}
