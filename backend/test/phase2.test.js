const { test, before, after, describe } = require('node:test');
const assert = require('node:assert/strict');
// Contract tests of the mobile JSON API served by the C# portal (admin-web must be running); see api.test.js.
const base = (process.env.API_BASE || 'http://localhost:8088').replace(/\/+$/, '');
const API_PREFIX = process.env.API_PREFIX || '/api/m';
const { closePool, run } = require('../db'); // direct DB access is only used to clean up the rows the tests create

const tokens = {};

after(() => closePool());

async function call(method, path, { body, headers } = {}) {
  const res = await fetch(base + path.replace(/^\/api/, API_PREFIX), {
    method,
    headers: { 'Content-Type': 'application/json', ...(headers || {}) },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch (_) {}
  return { status: res.status, json, text };
}

async function authed(email) {
  if (!tokens[email]) {
    const r = await call('POST', '/api/login', { body: { identifier: email, password: '123456' } });
    tokens[email] = { Authorization: `Bearer ${r.json.token}` };
  }
  return tokens[email];
}
const get = async (email, path) => call('GET', path, { headers: await authed(email) });
const post = async (email, path, body) => call('POST', path, { headers: await authed(email), body });

describe('protected routes need a token', () => {
  for (const p of ['/api/children', '/api/schedule', '/api/grades', '/api/requests', '/api/clubs']) {
    test(`GET ${p} without token -> 401`, async () => {
      assert.equal((await call('GET', p)).status, 401);
    });
  }
});

describe('children', () => {
  test('PH sees both linked children', async () => {
    const r = await get('ph@fschool.vn', '/api/children');
    assert.equal(r.status, 200);
    assert.deepEqual(r.json.map((s) => s.name).sort(), ['Hoc sinh Demo', 'Hoc sinh Mai']);
  });
  test('HS sees only themself', async () => {
    const r = await get('hs@fschool.vn', '/api/children');
    assert.deepEqual(r.json.map((s) => s.name), ['Hoc sinh Demo']);
  });
});

describe('schedule', () => {
  test('HS gets the class timetable', async () => {
    const r = await get('hs@fschool.vn', '/api/schedule');
    assert.equal(r.status, 200);
    assert.equal(r.json.className, '10A1');
    assert.equal(r.json.items.length, 29);
    const wedFirst = r.json.items.find((x) => x.dayOfWeek === 3 && x.period === 1);
    assert.equal(wedFirst.subject, 'Anh');
    assert.equal(wedFirst.startTime, '07:30');
    assert.equal(wedFirst.teacherName, 'Giao vien Lan');
  });
  test('GV only gets lessons they teach', async () => {
    const r = await get('gv@fschool.vn', '/api/schedule');
    assert.ok(r.json.items.length > 0 && r.json.items.length < 29);
    assert.ok(r.json.items.every((x) => x.teacherName === 'Giao vien Demo'));
  });
  test('PH with a foreign studentId -> 403', async () => {
    const r = await get('ph@fschool.vn', '/api/schedule?studentId=999999');
    assert.equal(r.status, 403);
  });
  test('detail of a lesson, bad id and missing id', async () => {
    const list = await get('hs@fschool.vn', '/api/schedule');
    const id = list.json.items[0].id;
    const ok = await get('hs@fschool.vn', `/api/schedule/${id}`);
    assert.equal(ok.status, 200);
    assert.equal(ok.json.id, id);
    assert.equal((await get('hs@fschool.vn', '/api/schedule/abc')).status, 400);
    assert.equal((await get('hs@fschool.vn', '/api/schedule/99999999')).status, 404);
  });
});

describe('grades', () => {
  test('summary for HS', async () => {
    const r = await get('hs@fschool.vn', '/api/grades');
    assert.equal(r.status, 200);
    assert.equal(r.json.subjects.length, 8);
    assert.equal(r.json.conduct, 'Tốt');
    assert.ok(r.json.average > 8 && r.json.average < 9);
    assert.equal(r.json.rank, 'Giỏi');
    const toan = r.json.subjects.find((s) => s.subject === 'Toán');
    assert.equal(toan.midterm, 9);
    assert.equal(toan.final, 9);
    assert.equal(toan.average, 8.85); // (9+8.5+9)*1 + (8.5+9)*2 + 9*3 = 88.5 over weight 10
  });
  test('PH picks a child with studentId', async () => {
    const kids = (await get('ph@fschool.vn', '/api/children')).json;
    const mai = kids.find((k) => k.name === 'Hoc sinh Mai');
    const r = await get('ph@fschool.vn', `/api/grades?studentId=${mai.id}`);
    assert.equal(r.json.student.name, 'Hoc sinh Mai');
  });
  test('GV needs studentId', async () => {
    assert.equal((await get('gv@fschool.vn', '/api/grades')).status, 400);
  });
  test('subject detail with weights and remark', async () => {
    const r = await get('hs@fschool.vn', `/api/grades/${encodeURIComponent('Toán')}`);
    assert.equal(r.status, 200);
    assert.equal(r.json.items.length, 6);
    assert.equal(r.json.items[0].type, 'Miệng');
    assert.equal(r.json.items[5].weight, 3);
    assert.equal(r.json.teacherName, 'Giao vien Demo');
    assert.match(r.json.comment, /tiếp thu tốt/);
  });
  test('unknown subject -> 404', async () => {
    assert.equal((await get('hs@fschool.vn', '/api/grades/Nope')).status, 404);
  });
});

describe('requests', () => {
  after(async () => {
    await run("DELETE FROM dbo.Requests WHERE reason LIKE 'TEST-%'");
  });

  const newReq = (extra = {}) => ({
    studentId: null,
    type: 'Xin nghỉ học',
    fromDate: '2026-11-02',
    toDate: '2026-11-03',
    reason: 'TEST-ốm',
    ...extra,
  });
  async function childId(email, name) {
    return (await get(email, '/api/children')).json.find((c) => c.name === name).id;
  }

  test('list is scoped per role and filterable', async () => {
    const ph = await get('ph@fschool.vn', '/api/requests');
    assert.ok(ph.json.length >= 4);
    const pending = await get('ph@fschool.vn', '/api/requests?status=pending');
    assert.ok(pending.json.every((x) => x.status === 'pending'));
    const hs = await get('hs@fschool.vn', '/api/requests');
    assert.ok(hs.json.every((x) => x.student.name === 'Hoc sinh Demo'));
    assert.equal((await get('ph@fschool.vn', '/api/requests?status=bogus')).status, 400);
  });

  test('PH creates, GV approves once, second decision -> 409', async () => {
    const sid = await childId('ph@fschool.vn', 'Hoc sinh Demo');
    const c = await post('ph@fschool.vn', '/api/requests', newReq({ studentId: sid }));
    assert.equal(c.status, 201);
    assert.equal(c.json.status, 'pending');
    assert.equal(c.json.creator.role, 'PH');
    const id = c.json.id;
    const d = await post('gv@fschool.vn', `/api/requests/${id}/decision`, { decision: 'approved', comment: 'Đồng ý' });
    assert.equal(d.status, 200);
    assert.equal(d.json.status, 'approved');
    assert.equal(d.json.teacherComment, 'Đồng ý');
    assert.equal(d.json.handledByName, 'Giao vien Demo');
    const again = await post('gv@fschool.vn', `/api/requests/${id}/decision`, { decision: 'rejected' });
    assert.equal(again.status, 409);
  });

  test('HS may create only for themself', async () => {
    const mine = await childId('hs@fschool.vn', 'Hoc sinh Demo');
    const other = await childId('ph@fschool.vn', 'Hoc sinh Mai');
    assert.equal(
      (await post('hs@fschool.vn', '/api/requests', newReq({ studentId: mine, type: 'Xin phép đi trễ' }))).status,
      201
    );
    assert.equal((await post('hs@fschool.vn', '/api/requests', newReq({ studentId: other }))).status, 403);
  });

  test('validation errors', async () => {
    const sid = await childId('hs@fschool.vn', 'Hoc sinh Demo');
    const bad = (extra) => post('hs@fschool.vn', '/api/requests', newReq({ studentId: sid, ...extra }));
    assert.equal((await bad({ type: 'Khác' })).status, 400);
    assert.equal((await bad({ reason: '  ' })).status, 400);
    assert.equal((await bad({ fromDate: '2026-02-30' })).status, 400);
    assert.equal((await bad({ fromDate: '2026-11-05', toDate: '2026-11-01' })).status, 400);
    assert.equal((await bad({ reason: 'x'.repeat(501) })).status, 400);
  });

  test('role gates', async () => {
    assert.equal((await post('gv@fschool.vn', '/api/requests', newReq({ studentId: 1 }))).status, 403);
    const list = await get('ph@fschool.vn', '/api/requests?status=pending');
    const id = list.json[0].id;
    assert.equal((await post('ph@fschool.vn', `/api/requests/${id}/decision`, { decision: 'approved' })).status, 403);
    assert.equal((await post('gv@fschool.vn', `/api/requests/${id}/decision`, { decision: 'maybe' })).status, 400);
  });

  test('detail: visible vs not found', async () => {
    const list = await get('ph@fschool.vn', '/api/requests');
    const id = list.json[0].id;
    assert.equal((await get('ph@fschool.vn', `/api/requests/${id}`)).status, 200);
    assert.equal((await get('ph@fschool.vn', '/api/requests/99999999')).status, 404);
  });
});

describe('clubs', () => {
  after(async () => {
    await run(
      "DELETE m FROM dbo.ClubMembers m JOIN dbo.Clubs c ON c.id = m.clubId JOIN dbo.Users u ON u.id = m.userId WHERE c.name = N'CLB Mỹ thuật' AND u.email = 'hs@fschool.vn'"
    );
  });

  test('list shows counts and my status', async () => {
    const r = await get('hs@fschool.vn', '/api/clubs');
    assert.equal(r.json.length, 5);
    assert.equal(r.json.find((c) => c.name === 'CLB Bóng đá').myStatus, 'approved');
    assert.equal(r.json.find((c) => c.name === 'CLB Âm nhạc').myStatus, 'pending');
    assert.equal(r.json.find((c) => c.name === 'CLB Lập trình').myStatus, null);
    assert.equal(r.json.find((c) => c.name === 'CLB Lập trình').memberCount, 56);
  });
  test('search is literal and case-insensitive', async () => {
    assert.equal((await get('hs@fschool.vn', '/api/clubs?q=l%E1%BA%ADp')).json.length, 1);
    assert.equal((await get('hs@fschool.vn', '/api/clubs?q=%25')).json.length, 0);
  });
  test('detail', async () => {
    const id = (await get('hs@fschool.vn', '/api/clubs')).json.find((c) => c.name === 'CLB Lập trình').id;
    const r = await get('hs@fschool.vn', `/api/clubs/${id}`);
    assert.equal(r.json.advisor, 'Thầy Lê Văn Hùng');
    assert.ok(Array.isArray(r.json.memberPreview));
    assert.equal((await get('hs@fschool.vn', '/api/clubs/99999999')).status, 404);
  });
  test('HS joins once; duplicate -> 409; others -> 403', async () => {
    const id = (await get('hs@fschool.vn', '/api/clubs')).json.find((c) => c.name === 'CLB Mỹ thuật').id;
    const a = await post('hs@fschool.vn', `/api/clubs/${id}/join`);
    assert.equal(a.status, 201);
    assert.equal(a.json.status, 'pending');
    assert.equal((await post('hs@fschool.vn', `/api/clubs/${id}/join`)).status, 409);
    assert.equal((await post('ph@fschool.vn', `/api/clubs/${id}/join`)).status, 403);
  });
});
