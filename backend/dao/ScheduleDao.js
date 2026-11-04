const { sql, query } = require('../db');

const COLS = `sc.id, sc.dayOfWeek, sc.period, sc.subject, sc.className, sc.room, sc.mode, sc.content, sc.prep, sc.note,
  CONVERT(varchar(5), sc.startTime, 108) AS startTime, CONVERT(varchar(5), sc.endTime, 108) AS endTime,
  t.name AS teacherName`;
const FROM = 'FROM dbo.Schedule sc JOIN dbo.Users t ON t.id = sc.teacherId';

class ScheduleDao {
  byClass(className) {
    return query(`SELECT ${COLS} ${FROM} WHERE sc.className = @c ORDER BY sc.dayOfWeek, sc.period`, {
      c: [sql.NVarChar(20), className],
    });
  }

  byTeacher(teacherId) {
    return query(`SELECT ${COLS} ${FROM} WHERE sc.teacherId = @t ORDER BY sc.dayOfWeek, sc.period`, {
      t: [sql.Int, teacherId],
    });
  }

  async findById(id) {
    const rows = await query(`SELECT ${COLS} ${FROM} WHERE sc.id = @id`, { id: [sql.Int, id] });
    return rows[0] || null;
  }
}

module.exports = new ScheduleDao();
module.exports.ScheduleDao = ScheduleDao;
