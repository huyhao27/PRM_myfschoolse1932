using System;
using System.Web;
using System.Web.Http;

namespace MyfschoolWeb
{
    public class Global : HttpApplication
    {
        protected void Application_Start(object sender, EventArgs e)
        {
            GlobalConfiguration.Configure(WebApiConfig.Register);
        }

        protected void Application_BeginRequest(object sender, EventArgs e)
        {
            // Mobile JSON API (/api/m): CORS allow-list, security headers, preflight (see MobileEdge)
            if (MyfschoolWeb.Controllers.Api.Mobile.MobileEdge.IsMobilePath(HttpContext.Current.Request.Path))
            {
                MyfschoolWeb.Controllers.Api.Mobile.MobileEdge.Begin(HttpContext.Current);
                return;
            }

            // Hỗ trợ CORS cho các cuộc gọi từ bên ngoài nếu có
            HttpContext.Current.Response.AddHeader("Access-Control-Allow-Origin", "*");
            if (HttpContext.Current.Request.HttpMethod == "OPTIONS")
            {
                HttpContext.Current.Response.AddHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
                HttpContext.Current.Response.AddHeader("Access-Control-Allow-Headers", "Content-Type, Accept, Authorization");
                HttpContext.Current.Response.AddHeader("Access-Control-Max-Age", "1728000");
                HttpContext.Current.Response.End();
            }
        }
    }
}
