using System;
using System.Collections.Generic;
using System.Configuration;

namespace MyfschoolWeb.Services
{
    /// <summary>
    /// In-memory sliding-window counter keyed by "identifier|client-ip". Not shared between processes/servers (demo-grade).
    /// Defaults: 5 events per 900 s; override with appSettings MobileRateLimitMax / MobileRateLimitWindowSeconds.
    /// </summary>
    public class MobileRateLimiter
    {
        private const int MaxKeys = 100000;
        private readonly object _lock = new object();
        private readonly Dictionary<string, Queue<long>> _hits = new Dictionary<string, Queue<long>>();
        private readonly int _max;
        private readonly long _windowTicks;
        private long _lastPrune;

        public MobileRateLimiter(int max, int windowSeconds)
        {
            _max = max;
            _windowTicks = TimeSpan.FromSeconds(windowSeconds).Ticks;
        }

        public static MobileRateLimiter FromConfig()
        {
            return new MobileRateLimiter(Cfg("MobileRateLimitMax", 5), Cfg("MobileRateLimitWindowSeconds", 900));
        }

        private static int Cfg(string key, int def)
        {
            int v;
            return int.TryParse(ConfigurationManager.AppSettings[key], out v) && v > 0 ? v : def;
        }

        private void Trim(Queue<long> q, long now)
        {
            while (q.Count > 0 && now - q.Peek() >= _windowTicks) q.Dequeue();
        }

        private int Wait(Queue<long> q, long now)
        {
            long ticks = _windowTicks - (now - q.Peek());
            return (int)Math.Max(1, Math.Ceiling(TimeSpan.FromTicks(ticks).TotalSeconds));
        }

        private void Prune(long now)
        {
            if (now - _lastPrune < TimeSpan.FromMinutes(1).Ticks && _hits.Count < MaxKeys) return;
            _lastPrune = now;
            var dead = new List<string>();
            foreach (var kv in _hits) { Trim(kv.Value, now); if (kv.Value.Count == 0) dead.Add(kv.Key); }
            foreach (var k in dead) _hits.Remove(k);
            if (_hits.Count >= MaxKeys) _hits.Clear();   // memory guard under a key-flooding attack
        }

        /// <summary>0 when the key may proceed, otherwise the seconds until it may try again (does not record anything).</summary>
        public int RetryAfter(string key)
        {
            lock (_lock)
            {
                long now = DateTime.UtcNow.Ticks;
                Queue<long> q;
                if (!_hits.TryGetValue(key, out q)) return 0;
                Trim(q, now);
                if (q.Count == 0) { _hits.Remove(key); return 0; }
                return q.Count >= _max ? Wait(q, now) : 0;
            }
        }

        /// <summary>Records one event for the key.</summary>
        public void Hit(string key)
        {
            lock (_lock)
            {
                long now = DateTime.UtcNow.Ticks;
                Prune(now);
                Queue<long> q;
                if (!_hits.TryGetValue(key, out q)) { q = new Queue<long>(); _hits[key] = q; }
                Trim(q, now);
                q.Enqueue(now);
            }
        }

        /// <summary>Atomically: 0 and records the call when under the limit, otherwise the seconds to wait.</summary>
        public int TryAcquire(string key)
        {
            lock (_lock)
            {
                long now = DateTime.UtcNow.Ticks;
                Prune(now);
                Queue<long> q;
                if (!_hits.TryGetValue(key, out q)) { q = new Queue<long>(); _hits[key] = q; }
                Trim(q, now);
                if (q.Count >= _max) return Wait(q, now);
                q.Enqueue(now);
                return 0;
            }
        }

        public void Clear(string key)
        {
            lock (_lock) { _hits.Remove(key); }
        }
    }
}
