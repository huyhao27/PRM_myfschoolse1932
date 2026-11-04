const requestDao = require('../dao/RequestDao');
const { HttpError, parseId, parseDate } = require('../lib/http');

const TYPES = ['Xin nghỉ học', 'Xin phép đi trễ', 'Xin đổi chỗ ngồi'];
const STATUSES = ['pending', 'approved', 'rejected'];
const MAX_TEXT = 500;

const isStr = (v) => typeof v === 'string';

function shape(r) {
  return {
    id: r.id,
    type: r.type,
    status: r.status,
    reason: r.reason,
    fromDate: r.fromDate,
    toDate: r.toDate,
    createdAt: r.createdAt,
    student: { id: r.studentId, name: r.studentName, className: r.className },
    creator: { name: r.creatorName, role: r.creatorRole },
    teacherComment: r.teacherComment,
    handledByName: r.handledByName,
    handledAt: r.handledAt,
  };
}

async function list(req, res) {
  const { status } = req.query;
  if (status !== undefined && !STATUSES.includes(status)) throw new HttpError(400, 'Invalid status filter');
  res.json((await requestDao.list(req.user, status)).map(shape));
}

async function detail(req, res) {
  const r = await requestDao.findVisible(req.user, parseId(req.params.id));
  if (!r) throw new HttpError(404, 'Request not found');
  res.json(shape(r));
}

// HS (for themselves) and PH (for a linked child) create requests.
async function create(req, res) {
  const b = req.body || {};
  const studentId = Number.isInteger(b.studentId) ? b.studentId : NaN;
  if (!(studentId > 0)) throw new HttpError(400, 'studentId is required');
  if (!TYPES.includes(b.type)) throw new HttpError(400, 'Invalid request type');
  const reason = isStr(b.reason) ? b.reason.trim() : '';
  if (!reason) throw new HttpError(400, 'reason is required');
  if (reason.length > MAX_TEXT) throw new HttpError(400, `reason must be at most ${MAX_TEXT} characters`);
  const fromDate = parseDate(b.fromDate);
  if (!fromDate) throw new HttpError(400, 'fromDate must be a date (YYYY-MM-DD)');
  let toDate = fromDate;
  if (b.toDate !== undefined && b.toDate !== null && b.toDate !== '') {
    toDate = parseDate(b.toDate);
    if (!toDate) throw new HttpError(400, 'toDate must be a date (YYYY-MM-DD)');
    if (toDate < fromDate) throw new HttpError(400, 'toDate must not be before fromDate');
  }
  if (!(await requestDao.studentVisible(req.user, studentId))) {
    throw new HttpError(403, 'You cannot create a request for this student');
  }
  const id = await requestDao.create({ studentId, createdBy: req.user.id, type: b.type, fromDate, toDate, reason });
  res.status(201).json(shape(await requestDao.findVisible(req.user, id)));
}

// GV/Manager approve or reject a pending request they can see.
async function decide(req, res) {
  const id = parseId(req.params.id);
  const b = req.body || {};
  if (b.decision !== 'approved' && b.decision !== 'rejected') {
    throw new HttpError(400, 'decision must be "approved" or "rejected"');
  }
  let comment = null;
  if (b.comment !== undefined && b.comment !== null) {
    if (!isStr(b.comment)) throw new HttpError(400, 'comment must be text');
    comment = b.comment.trim() || null;
    if (comment && comment.length > MAX_TEXT) throw new HttpError(400, `comment must be at most ${MAX_TEXT} characters`);
  }
  const existing = await requestDao.findVisible(req.user, id);
  if (!existing) throw new HttpError(404, 'Request not found');
  if (!(await requestDao.decide(id, req.user.id, b.decision, comment))) {
    throw new HttpError(409, 'Request was already handled');
  }
  res.json(shape(await requestDao.findVisible(req.user, id)));
}

module.exports = { list, detail, create, decide, TYPES };
