const { sql, query } = require('../db');

class GradeDao {
  byStudentTerm(studentId, term) {
    return query(
      `SELECT subject, type, weight, CAST(score AS float) AS score, CONVERT(varchar(10), gradeDate, 23) AS date
       FROM dbo.Grade WHERE studentId = @s AND term = @t ORDER BY subject, gradeDate, id`,
      { s: [sql.Int, studentId], t: [sql.NVarChar(20), term] }
    );
  }

  async remark(studentId, subject, term) {
    const rows = await query(
      `SELECT r.comment, u.name AS teacherName FROM dbo.GradeRemark r JOIN dbo.Users u ON u.id = r.teacherId
       WHERE r.studentId = @s AND r.subject = @sub AND r.term = @t`,
      { s: [sql.Int, studentId], sub: [sql.NVarChar(100), subject], t: [sql.NVarChar(20), term] }
    );
    return rows[0] || null;
  }

  async conduct(studentId, term) {
    const rows = await query('SELECT conduct FROM dbo.TermSummary WHERE studentId = @s AND term = @t', {
      s: [sql.Int, studentId],
      t: [sql.NVarChar(20), term],
    });
    return rows[0] ? rows[0].conduct : null;
  }
}

module.exports = new GradeDao();
module.exports.GradeDao = GradeDao;
