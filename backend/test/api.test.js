const { test, before, after, describe } = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const app = require('../server');
const { closePool } = require('../db');

let server;
let base;

before(async () => {
  await new Promise((resolve) => {
    server = app.listen(0, '127.0.0.1', resolve);
  });
  base = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await new Promise((r) => server.close(r));
  await closePool();
});

async function call(method, path, { body, raw, headers } = {}) {
  const res = await fetch(base + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(headers || {}) },
    body: raw !== undefined ? raw : body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch (_) {}
  return { status: res.status, json, text };
}

const login = (identifier, password) =>
  call('POST', '/api/login', { body: { identifier, password } });

describe('health', () => {
  test('GET /api/health', async () => {
    const r = await call('GET', '/api/health');
    assert.equal(r.status, 200);
    assert.deepEqual(r.json, { status: 'ok' });
  });
});

describe('login', () => {
  for (const [email, role] of [
    ['gv@fschool.vn', 'GV'],
    ['manager@fschool.vn', 'Manager'],
    ['ph@fschool.vn', 'PH'],
    ['hs@fschool.vn', 'HS'],
  ]) {
    test(`success as ${role}`, async () => {
      const r = await login(email, '123456');
      assert.equal(r.status, 200);
      assert.equal(typeof r.json.token, 'string');
      assert.equal(r.json.user.role, role);
      assert.equal(r.json.user.email, email);
      assert.deepEqual(Object.keys(r.json.user).sort(), ['email', 'id', 'name', 'phone', 'role']);
      assert.ok(!r.text.includes('passwordHash'));
      assert.ok(!r.text.includes('$2'));
    });
  }

  test('success by phone', async () => {
    const r = await login('0901234567', '123456');
    assert.equal(r.status, 200);
    assert.equal(r.json.user.role, 'PH');
  });

  test('email case-insensitive and trimmed', async () => {
    const r = await login('  GV@FSchool.VN  ', '123456');
    assert.equal(r.status, 200);
    assert.equal(r.json.user.role, 'GV');
  });

  test('phone trimmed', async () => {
    const r = await login(' 0901234567 ', '123456');
    assert.equal(r.status, 200);
  });

  test('wrong password -> 401', async () => {
    const r = await login('gv@fschool.vn', 'wrong-pass');
    assert.equal(r.status, 401);
    assert.deepEqual(r.json, { message: 'Invalid credentials' });
  });

  test('unknown user -> 401 identical message', async () => {
    const r = await login('nobody@fschool.vn', '123456');
    const w = await login('gv@fschool.vn', 'wrong-pass');
    assert.equal(r.status, 401);
    assert.equal(r.text, w.text);
  });

  test('empty body -> 400', async () => {
    const r = await call('POST', '/api/login', { body: {} });
    assert.equal(r.status, 400);
    assert.equal(typeof r.json.message, 'string');
  });

  test('no body at all -> 400', async () => {
    const r = await call('POST', '/api/login');
    assert.equal(r.status, 400);
  });

  test('missing password -> 400', async () => {
    const r = await call('POST', '/api/login', { body: { identifier: 'gv@fschool.vn' } });
    assert.equal(r.status, 400);
  });

  test('empty-string fields -> 400', async () => {
    assert.equal((await login('   ', '123456')).status, 400);
    assert.equal((await login('gv@fschool.vn', '')).status, 400);
  });

  test('non-string identifier -> 400', async () => {
    for (const v of [123, null, true, { $ne: '' }, ['gv@fschool.vn']]) {
      const r = await call('POST', '/api/login', { body: { identifier: v, password: '123456' } });
      assert.equal(r.status, 400, JSON.stringify(v));
    }
  });

  test('non-string password -> 400', async () => {
    const r = await call('POST', '/api/login', {
      body: { identifier: 'gv@fschool.vn', password: 123456 },
    });
    assert.equal(r.status, 400);
  });

  test('SQL injection identifiers -> 401', async () => {
    for (const inj of [
      "' OR 1=1 --",
      "gv@fschool.vn' --",
      "'; DROP TABLE Users; --",
      "' OR '1'='1",
    ]) {
      const r = await login(inj, 'x');
      assert.equal(r.status, 401, inj);
      const r2 = await login(inj, '123456');
      assert.equal(r2.status, 401, inj);
    }
    // table still alive
    assert.equal((await login('gv@fschool.vn', '123456')).status, 200);
  });

  test('SQL injection in password -> 401', async () => {
    const r = await login('gv@fschool.vn', "' OR 1=1 --");
    assert.equal(r.status, 401);
  });

  test('very long input -> 401, no crash', async () => {
    const r = await login('a'.repeat(5000) + '@x.com', 'p'.repeat(5000));
    assert.equal(r.status, 401);
    const r2 = await login('gv@fschool.vn', 'p'.repeat(20000));
    assert.equal(r2.status, 401);
  });

  test('oversized payload -> 413 JSON', async () => {
    const r = await call('POST', '/api/login', {
      body: { identifier: 'a'.repeat(300000), password: 'x' },
    });
    assert.equal(r.status, 413);
    assert.equal(typeof r.json.message, 'string');
  });

  test('malformed JSON -> 400 JSON error', async () => {
    const r = await call('POST', '/api/login', { raw: '{"identifier": "gv@fschool.vn", ' });
    assert.equal(r.status, 400);
    assert.equal(typeof r.json.message, 'string');
    assert.ok(!r.text.includes('at '));
  });
});

describe('/api/me', () => {
  test('valid token', async () => {
    const l = await login('hs@fschool.vn', '123456');
    const r = await call('GET', '/api/me', {
      headers: { Authorization: `Bearer ${l.json.token}` },
    });
    assert.equal(r.status, 200);
    assert.equal(r.json.email, 'hs@fschool.vn');
    assert.equal(r.json.role, 'HS');
    assert.ok(!r.text.includes('passwordHash'));
  });

  test('token expires in about 1h', async () => {
    const l = await login('hs@fschool.vn', '123456');
    const p = jwt.decode(l.json.token);
    assert.equal(p.exp - p.iat, 3600);
  });

  test('missing token -> 401', async () => {
    const r = await call('GET', '/api/me');
    assert.equal(r.status, 401);
    assert.equal(typeof r.json.message, 'string');
  });

  test('garbage token -> 401', async () => {
    for (const h of ['Bearer garbage', 'Bearer', 'Basic abc', 'Bearer a.b.c']) {
      const r = await call('GET', '/api/me', { headers: { Authorization: h } });
      assert.equal(r.status, 401, h);
      assert.equal(typeof r.json.message, 'string');
    }
  });

  test('token signed with wrong secret -> 401', async () => {
    const t = jwt.sign({ sub: 1 }, 'not-the-secret', { expiresIn: '1h' });
    const r = await call('GET', '/api/me', { headers: { Authorization: `Bearer ${t}` } });
    assert.equal(r.status, 401);
  });

  test('alg=none token -> 401', async () => {
    const b = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
    const t = `${b({ alg: 'none', typ: 'JWT' })}.${b({ sub: 1 })}.`;
    const r = await call('GET', '/api/me', { headers: { Authorization: `Bearer ${t}` } });
    assert.equal(r.status, 401);
  });

  test('expired token -> 401', async () => {
    const t = jwt.sign({ sub: 1 }, process.env.JWT_SECRET, { expiresIn: -10 });
    const r = await call('GET', '/api/me', { headers: { Authorization: `Bearer ${t}` } });
    assert.equal(r.status, 401);
    assert.equal(typeof r.json.message, 'string');
  });
});

describe('reset-password', () => {
  test('reset, login with new, login old fails, then restore', async () => {
    const id = 'gv@fschool.vn';
    try {
      const r = await call('POST', '/api/reset-password', {
        body: { identifier: ` ${id.toUpperCase()} `, newPassword: 'newpass789' },
      });
      assert.equal(r.status, 200);
      assert.equal(typeof r.json.message, 'string');
      assert.ok(!r.text.includes('$2'));
      assert.equal((await login(id, 'newpass789')).status, 200);
      assert.equal((await login(id, '123456')).status, 401);
    } finally {
      const back = await call('POST', '/api/reset-password', {
        body: { identifier: id, newPassword: '123456' },
      });
      assert.equal(back.status, 200);
    }
    assert.equal((await login(id, '123456')).status, 200);
  });

  test('reset by phone works', async () => {
    try {
      const r = await call('POST', '/api/reset-password', {
        body: { identifier: '0901234567', newPassword: 'phonepass1' },
      });
      assert.equal(r.status, 200);
      assert.equal((await login('ph@fschool.vn', 'phonepass1')).status, 200);
    } finally {
      await call('POST', '/api/reset-password', {
        body: { identifier: '0901234567', newPassword: '123456' },
      });
    }
    assert.equal((await login('ph@fschool.vn', '123456')).status, 200);
  });

  test('too short -> 400 and password unchanged', async () => {
    const r = await call('POST', '/api/reset-password', {
      body: { identifier: 'gv@fschool.vn', newPassword: '12345' },
    });
    assert.equal(r.status, 400);
    assert.equal((await login('gv@fschool.vn', '123456')).status, 200);
  });

  test('missing / non-string newPassword -> 400', async () => {
    for (const body of [
      { identifier: 'gv@fschool.vn' },
      { identifier: 'gv@fschool.vn', newPassword: 1234567 },
      {},
    ]) {
      const r = await call('POST', '/api/reset-password', { body });
      assert.equal(r.status, 400, JSON.stringify(body));
    }
  });

  test('unknown user -> 404', async () => {
    const r = await call('POST', '/api/reset-password', {
      body: { identifier: 'ghost@fschool.vn', newPassword: 'abcdef12' },
    });
    assert.equal(r.status, 404);
    assert.equal(typeof r.json.message, 'string');
  });

  test('SQL injection identifier -> 404', async () => {
    const r = await call('POST', '/api/reset-password', {
      body: { identifier: "' OR 1=1 --", newPassword: 'abcdef12' },
    });
    assert.equal(r.status, 404);
    assert.equal((await login('gv@fschool.vn', '123456')).status, 200);
  });
});

describe('misc', () => {
  test('unknown route -> 404 JSON', async () => {
    const r = await call('GET', '/api/nope');
    assert.equal(r.status, 404);
    assert.equal(typeof r.json.message, 'string');
  });

  test('CORS header present', async () => {
    const res = await fetch(base + '/api/health', { headers: { Origin: 'http://localhost:5555' } });
    assert.ok(res.headers.get('access-control-allow-origin'));
  });
});
