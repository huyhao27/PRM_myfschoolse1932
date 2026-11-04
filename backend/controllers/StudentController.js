const access = require('../dao/AccessDao');
const { HttpError, parseId } = require('../lib/http');

// Student a request is about: ?studentId= when given, otherwise the user's own / first child.
async function resolveStudent(user, rawStudentId) {
  const students = await access.visibleStudents(user);
  if (rawStudentId !== undefined) {
    const id = parseId(String(rawStudentId), 'studentId');
    const s = students.find((x) => x.id === id);
    if (!s) throw new HttpError(403, 'You cannot view this student');
    return s;
  }
  if (user.role === 'HS' || user.role === 'PH') {
    if (!students.length) throw new HttpError(404, 'No student linked to this account');
    return students[0];
  }
  throw new HttpError(400, 'studentId is required');
}

// GET /api/children: the students this account can act for (own record for HS, linked children for PH, ...).
async function children(req, res) {
  res.json(await access.visibleStudents(req.user));
}

module.exports = { resolveStudent, children };
