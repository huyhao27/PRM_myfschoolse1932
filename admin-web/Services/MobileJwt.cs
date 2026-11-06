using System;
using System.Configuration;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace MyfschoolWeb.Services
{
    public enum JwtStatus { Ok, Invalid, Expired }

    /// <summary>
    /// Standard JWT (HS256) written by hand with HMACSHA256, interoperable with the Node API (jsonwebtoken).
    /// The secret is appSettings "JwtSecret" (admin-web\secrets.config, generated from backend\.env JWT_SECRET) and is never logged.
    /// Only alg HS256 is accepted; the signature is compared in constant time.
    /// </summary>
    public static class MobileJwt
    {
        public const int LifetimeSeconds = 3600;
        private static readonly Regex B64Url = new Regex("^[A-Za-z0-9_-]*$", RegexOptions.Compiled);

        private static byte[] Key()
        {
            string s = ConfigurationManager.AppSettings["JwtSecret"];
            if (string.IsNullOrEmpty(s) || s.Length < 16 || s.StartsWith("CHANGE_ME", StringComparison.Ordinal))
                throw new InvalidOperationException("JwtSecret is not configured (run tools\\gen-connection.ps1 to create secrets.config).");
            return Encoding.UTF8.GetBytes(s);
        }

        public static string Base64UrlEncode(byte[] data)
        {
            return Convert.ToBase64String(data).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        }

        private static byte[] Base64UrlDecode(string s)
        {
            if (s == null || !B64Url.IsMatch(s) || s.Length % 4 == 1) throw new FormatException("bad base64url");
            string t = s.Replace('-', '+').Replace('_', '/');
            switch (t.Length % 4) { case 2: t += "=="; break; case 3: t += "="; break; }
            return Convert.FromBase64String(t);
        }

        private static byte[] Sign(string signingInput)
        {
            using (var h = new HMACSHA256(Key())) return h.ComputeHash(Encoding.ASCII.GetBytes(signingInput));
        }

        private static bool FixedTimeEquals(byte[] a, byte[] b)
        {
            int diff = a.Length ^ b.Length;
            for (int i = 0; i < a.Length && i < b.Length; i++) diff |= a[i] ^ b[i];
            return diff == 0;
        }

        public static string Create(int userId, string role)
        {
            long now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            string header = Base64UrlEncode(Encoding.UTF8.GetBytes("{\"alg\":\"HS256\",\"typ\":\"JWT\"}"));
            var p = new JObject { { "sub", userId }, { "role", role }, { "iat", now }, { "exp", now + LifetimeSeconds } };
            string payload = Base64UrlEncode(Encoding.UTF8.GetBytes(p.ToString(Formatting.None)));
            string input = header + "." + payload;
            return input + "." + Base64UrlEncode(Sign(input));
        }

        private static JObject ParseObject(byte[] bytes)
        {
            using (var sr = new System.IO.StringReader(Encoding.UTF8.GetString(bytes)))
            using (var jr = new JsonTextReader(sr) { DateParseHandling = DateParseHandling.None })
            {
                var t = JToken.Load(jr);
                return t as JObject;
            }
        }

        /// <summary>Checks signature (HS256 only), then exp. Same order as jsonwebtoken: a forged token is "Invalid" even when expired.</summary>
        public static JwtStatus Verify(string token, out int sub)
        {
            sub = 0;
            try
            {
                string[] parts = (token ?? "").Split('.');
                if (parts.Length != 3 || parts[0].Length == 0 || parts[1].Length == 0 || parts[2].Length == 0) return JwtStatus.Invalid;
                JObject header = ParseObject(Base64UrlDecode(parts[0]));
                if (header == null) return JwtStatus.Invalid;
                JToken alg = header["alg"];
                if (alg == null || alg.Type != JTokenType.String || (string)alg != "HS256") return JwtStatus.Invalid;
                byte[] sig = Base64UrlDecode(parts[2]);
                if (!FixedTimeEquals(Sign(parts[0] + "." + parts[1]), sig)) return JwtStatus.Invalid;

                JObject payload = ParseObject(Base64UrlDecode(parts[1]));
                if (payload == null) return JwtStatus.Invalid;
                JToken exp = payload["exp"];
                if (exp == null || (exp.Type != JTokenType.Integer && exp.Type != JTokenType.Float)) return JwtStatus.Invalid;
                if (DateTimeOffset.UtcNow.ToUnixTimeSeconds() >= (long)Math.Floor((double)exp)) return JwtStatus.Expired;
                JToken s = payload["sub"];
                if (s == null || s.Type != JTokenType.Integer) return JwtStatus.Invalid;
                long v = (long)s;
                if (v < 1 || v > int.MaxValue) return JwtStatus.Invalid;
                sub = (int)v;
                return JwtStatus.Ok;
            }
            catch (InvalidOperationException) { throw; }   // missing secret = server misconfiguration -> 500, not 401
            catch (Exception) { return JwtStatus.Invalid; }
        }
    }
}
