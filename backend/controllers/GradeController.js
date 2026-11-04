const gradeDao = require('../dao/GradeDao');
const { resolveStudent } = require('./StudentController');
const { HttpError } = require('../lib/http');

const DEFAULT_TERM = 'HK1';

const round2 = (n) => Math.round(n * 100) / 100;

// Weighted mean of {score, weight} rows.
function weighted(rows) {
  const w = rows.reduce((a, r) => a + r.weight, 0);
  return w ? round2(rows.reduce((a, r) => a + r.score * r.weight, 0) / w) : null;
}

function rankOf(avg) {
  if (avg === null) return null;
  if (avg >= 8) return 'Giỏi';
  if (avg >= 6.5) return 'Khá';
  if (avg >= 5) return 'Trung bình';
  return 'Yếu';
}

const mean = (rows, type) => {
  const r = rows.filter((x) => x.type === type);
  return r.length ? round2(r.reduce((a, x) => a + x.score, 0) / r.length) : null;
};

function termOf(req) {
  const t = req.query.term;
  return typeof t === 'string' && /^[A-Za-z0-9]{1,20}$/.test(t) ? t : DEFAULT_TERM;
}

// Summary per subject plus overall average, rank and conduct.
async function list(req, res) {
  const student = await resolveStudent(req.user, req.query.studentId);
  const term = termOf(req);
  const rows = await gradeDao.byStudentTerm(student.id, term);
  const bySubject = new Map();
  for (const r of rows) {
    if (!bySubject.has(r.subject)) bySubject.set(r.subject, []);
    bySubject.get(r.subject).push(r);
  }
  const subjects = [...bySubject].map(([subject, items]) => ({
    subject,
    midterm: mean(items, 'Giữa kỳ'),
    final: mean(items, 'Cuối kỳ'),
    average: weighted(items),
  }));
  const avgs = subjects.map((s) => s.average).filter((a) => a !== null);
  const average = avgs.length ? round2(avgs.reduce((a, b) => a + b, 0) / avgs.length) : null;
  res.json({
    student: { id: student.id, name: student.name, className: student.className },
    term,
    average,
    rank: rankOf(average),
    conduct: await gradeDao.conduct(student.id, term),
    subjects,
  });
}

// All score entries of one subject, with the teacher's remark.
async function detail(req, res) {
  const student = await resolveStudent(req.user, req.query.studentId);
  const term = termOf(req);
  const subject = req.params.subject;
  const items = (await gradeDao.byStudentTerm(student.id, term)).filter((r) => r.subject === subject);
  if (!items.length) throw new HttpError(404, 'No grades for this subject');
  const remark = await gradeDao.remark(student.id, subject, term);
  res.json({
    student: { id: student.id, name: student.name, className: student.className },
    term,
    subject,
    average: weighted(items),
    teacherName: remark ? remark.teacherName : null,
    comment: remark ? remark.comment : null,
    items: items.map((r) => ({ type: r.type, weight: r.weight, score: r.score, date: r.date })),
  });
}

module.exports = { list, detail };
