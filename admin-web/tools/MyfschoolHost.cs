// Minimal self-host for ASP.NET Web Forms + Web API (Cassini-style) because IIS / IIS Express are not installed.
// Usage: MyfschoolHost.exe <physicalPath> <port>
// The exe must sit in <physicalPath>\bin (tools\run.ps1 copies it there) so the app domain can load it.
using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Threading;
using System.Web;
using System.Web.Hosting;

public class HostProgram
{
    public static int Main(string[] args)
    {
        string path = Path.GetFullPath(args.Length > 0 ? args[0] : ".");
        int port = args.Length > 1 ? int.Parse(args[1]) : 8088;
        try
        {
            var host = (AppHost)ApplicationHost.CreateApplicationHost(typeof(AppHost), "/", path);
            host.Start(port, path);
            Console.WriteLine("MyfschoolHost listening on http://localhost:" + port + "/  (path " + path + ")");
            Thread.Sleep(Timeout.Infinite);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("HOST START FAILED: " + ex);
            return 1;
        }
        return 0;
    }
}

public class AppHost : MarshalByRefObject
{
    HttpListener _listener;
    string _root;

    public override object InitializeLifetimeService() { return null; }

    public void Start(int port, string root)
    {
        _root = root.TrimEnd('\\');
        _listener = new HttpListener();
        _listener.Prefixes.Add("http://localhost:" + port + "/");
        _listener.Start();
        var t = new Thread(Loop) { IsBackground = false };
        t.Start();
    }

    void Loop()
    {
        while (_listener.IsListening)
        {
            HttpListenerContext ctx;
            try { ctx = _listener.GetContext(); } catch { break; }
            ThreadPool.QueueUserWorkItem(_ => Handle(ctx));
        }
    }

    void Handle(HttpListenerContext ctx)
    {
        try
        {
            var wr = new ListenerWorkerRequest(ctx, _root);
            HttpRuntime.ProcessRequest(wr);
        }
        catch (Exception ex)
        {
            try
            {
                ctx.Response.StatusCode = 500;
                var b = System.Text.Encoding.UTF8.GetBytes("Host error: " + ex);
                ctx.Response.OutputStream.Write(b, 0, b.Length);
                ctx.Response.Close();
            }
            catch { }
        }
    }
}

public class ListenerWorkerRequest : HttpWorkerRequest
{
    readonly HttpListenerContext _ctx;
    readonly string _root;
    readonly string _path;       // url path without query, default document applied
    readonly string _query;
    byte[] _body;
    bool _closed;

    public ListenerWorkerRequest(HttpListenerContext ctx, string root)
    {
        _ctx = ctx;
        _root = root;
        // LocalPath is percent-decoded (what IIS hands to ASP.NET); AbsolutePath keeps %xx and ASP.NET would reject the "%".
        string p = ctx.Request.Url.LocalPath;
        if (p == "/" || p == "") p = "/Default.aspx";
        _path = p;
        string q = ctx.Request.Url.Query;
        _query = string.IsNullOrEmpty(q) ? "" : q.Substring(1);
        using (var ms = new MemoryStream())
        {
            if (ctx.Request.HasEntityBody) ctx.Request.InputStream.CopyTo(ms);
            _body = ms.ToArray();
        }
    }

    public override string GetUriPath() { return _path; }
    public override string GetQueryString() { return _query; }
    public override string GetRawUrl() { return _path + (_query.Length > 0 ? "?" + _query : ""); }
    public override string GetHttpVerbName() { return _ctx.Request.HttpMethod; }
    public override string GetHttpVersion() { return "HTTP/" + _ctx.Request.ProtocolVersion.ToString(2); }
    public override string GetRemoteAddress() { return _ctx.Request.RemoteEndPoint.Address.ToString(); }
    public override int GetRemotePort() { return _ctx.Request.RemoteEndPoint.Port; }
    public override string GetLocalAddress() { return _ctx.Request.LocalEndPoint.Address.ToString(); }
    public override int GetLocalPort() { return _ctx.Request.LocalEndPoint.Port; }
    public override string GetServerName() { return "localhost"; }
    public override bool IsSecure() { return false; }
    public override string GetProtocol() { return "http"; }
    public override string GetAppPath() { return "/"; }
    public override string GetAppPathTranslated() { return _root + "\\"; }
    public override string GetFilePath() { return _path; }
    public override string GetPathInfo() { return ""; }
    public override string GetFilePathTranslated() { return MapPath(_path); }

    public override string MapPath(string virtualPath)
    {
        string v = virtualPath ?? "/";
        if (v.StartsWith("~")) v = v.Substring(1);
        if (!v.StartsWith("/")) v = "/" + v;
        v = v.Replace('/', '\\');
        return _root + v;
    }

    public override byte[] GetPreloadedEntityBody() { return _body; }
    public override bool IsEntireEntityBodyIsPreloaded() { return true; }
    public override int ReadEntityBody(byte[] buffer, int size) { return 0; }
    public override long GetBytesRead() { return _body.Length; }

    public override string GetKnownRequestHeader(int index)
    {
        if (index == HeaderContentLength) return _ctx.Request.HasEntityBody ? _body.Length.ToString() : null;
        return _ctx.Request.Headers[GetKnownRequestHeaderName(index)];
    }

    public override string[][] GetUnknownRequestHeaders()
    {
        var list = new List<string[]>();
        foreach (string key in _ctx.Request.Headers.AllKeys)
        {
            if (GetKnownRequestHeaderIndex(key) >= 0) continue;
            list.Add(new[] { key, _ctx.Request.Headers[key] });
        }
        return list.ToArray();
    }

    // ---- response ----
    public override void SendStatus(int statusCode, string statusDescription)
    {
        _ctx.Response.StatusCode = statusCode;
        _ctx.Response.StatusDescription = statusDescription;
    }

    public override void SendKnownResponseHeader(int index, string value)
    {
        switch (index)
        {
            case HeaderContentLength:
                _ctx.Response.ContentLength64 = long.Parse(value);
                return;
            case HeaderContentType:
                _ctx.Response.ContentType = FixMime(value);
                return;
            case HeaderTransferEncoding:
            case HeaderKeepAlive:
            case HeaderConnection:
            case HeaderWwwAuthenticate:
                return;
            case HeaderSetCookie:
                _ctx.Response.Headers.Add("Set-Cookie", value);
                return;
            case HeaderLocation:
                _ctx.Response.RedirectLocation = value;
                return;
        }
        _ctx.Response.AppendHeader(GetKnownResponseHeaderName(index), value);
    }

    // The classic-pipeline static file handler does not know some modern types (it answers application/octet-stream).
    string FixMime(string value)
    {
        if (value == null || !value.StartsWith("application/octet-stream", StringComparison.OrdinalIgnoreCase)) return value;
        switch (Path.GetExtension(_path).ToLowerInvariant())
        {
            case ".svg": return "image/svg+xml";
            case ".webp": return "image/webp";
            case ".woff": return "font/woff";
            case ".woff2": return "font/woff2";
            case ".json": return "application/json";
            case ".map": return "application/json";
        }
        return value;
    }

    public override void SendUnknownResponseHeader(string name, string value)
    {
        _ctx.Response.AppendHeader(name, value);
    }

    public override void SendResponseFromMemory(byte[] data, int length)
    {
        if (length > 0) _ctx.Response.OutputStream.Write(data, 0, length);
    }

    public override void SendResponseFromFile(string filename, long offset, long length)
    {
        using (var fs = new FileStream(filename, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            CopyFile(fs, offset, length);
    }

    public override void SendResponseFromFile(IntPtr handle, long offset, long length)
    {
        using (var sh = new Microsoft.Win32.SafeHandles.SafeFileHandle(handle, false))
        using (var fs = new FileStream(sh, FileAccess.Read))
            CopyFile(fs, offset, length);
    }

    void CopyFile(FileStream fs, long offset, long length)
    {
        if (length == 0) return;
        if (length < 0) length = fs.Length - offset;
        fs.Seek(offset, SeekOrigin.Begin);
        var buf = new byte[65536];
        while (length > 0)
        {
            int n = fs.Read(buf, 0, (int)Math.Min(buf.Length, length));
            if (n <= 0) break;
            _ctx.Response.OutputStream.Write(buf, 0, n);
            length -= n;
        }
    }

    public override void FlushResponse(bool finalFlush)
    {
        try { _ctx.Response.OutputStream.Flush(); } catch { }
    }

    public override void EndOfRequest()
    {
        if (_closed) return;
        _closed = true;
        try { _ctx.Response.OutputStream.Close(); } catch { }
        try { _ctx.Response.Close(); } catch { }
    }
}
