const scheduleDao = require('../dao/ScheduleDao');
const { resolveStudent } = require('./StudentController');
const { HttpError, parseId } = require('../lib/http');

const DEFAULT_CLASS = '10A1';

// Weekly timetable. HS/PH: the student's class. GV: the lessons they teach. Manager: ?className= (default 10A1).
async function list(req, res) {
  const { user } = req;
  let items;
  let className = null;
  if (user.role === 'GV') {
    items = await scheduleDao.byTeacher(user.id);
  } else if (user.role === 'Manager') {
    className = typeof req.query.className === 'string' && req.query.className ? req.query.className : DEFAULT_CLASS;
    items = await scheduleDao.byClass(className);
  } else {
    const student = await resolveStudent(user, req.query.studentId);
    className = student.className;
    items = await scheduleDao.byClass(className);
  }
  res.json({ className, items });
}

async function detail(req, res) {
  const id = parseId(req.params.id);
  const item = await scheduleDao.findById(id);
  if (!item) throw new HttpError(404, 'Lesson not found');
  const { user } = req;
  if (user.role === 'GV') {
    const own = (await scheduleDao.byTeacher(user.id)).some((x) => x.id === id);
    if (!own) throw new HttpError(404, 'Lesson not found');
  } else if (user.role === 'HS' || user.role === 'PH') {
    const student = await resolveStudent(user, req.query.studentId);
    if (student.className !== item.className) throw new HttpError(404, 'Lesson not found');
  }
  res.json(item);
}

module.exports = { list, detail };
