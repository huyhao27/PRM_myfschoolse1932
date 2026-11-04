const { sql, query, run } = require('../db');
const access = require('./AccessDao');

const SELECT = `SELECT r.id, r.type, r.status, r.reason, r.teacherComment,
  CONVERT(varchar(10), r.fromDate, 23) AS fromDate, CONVERT(varchar(10), r.toDate, 23) AS toDate,
  CONVERT(varchar(19), r.createdAt, 126) AS createdAt, CONVERT(varchar(19), r.handledAt, 126) AS handledAt,
  s.id AS studentId, s.name AS studentName, s.className,
  c.name AS creatorName, c.role AS creatorRole, h.name AS handledByName
  FROM dbo.Requests r
  JOIN dbo.Users s ON s.id = r.studentId
  JOIN dbo.Users c ON c.id = r.createdBy
  LEFT JOIN dbo.Users h ON h.id = r.handledBy`;

class RequestDao {
  list(user, status) {
    const where = [access.studentScope(user.role, 's')];
    const params = { uid: [sql.Int, user.id] };
    if (status) {
      where.push('r.status = @status');
      params.status = [sql.VarChar(10), status];
    }
    return query(`${SELECT} WHERE ${where.join(' AND ')} ORDER BY r.createdAt DESC, r.id DESC`, params);
  }

  async findVisible(user, id) {
    const rows = await query(`${SELECT} WHERE r.id = @id AND ${access.studentScope(user.role, 's')}`, {
      id: [sql.Int, id],
      uid: [sql.Int, user.id],
    });
    return rows[0] || null;
  }

  async studentVisible(user, studentId) {
    const rows = await query(
      `SELECT s.id FROM dbo.Users s WHERE s.id = @sid AND ${access.studentScope(user.role, 's')}`,
      { sid: [sql.Int, studentId], uid: [sql.Int, user.id] }
    );
    return rows.length > 0;
  }

  async create({ studentId, createdBy, type, fromDate, toDate, reason }) {
    const r = await query(
      `INSERT dbo.Requests (studentId, createdBy, type, fromDate, toDate, reason)
       OUTPUT INSERTED.id VALUES (@sid, @by, @type, @from, @to, @reason)`,
      {
        sid: [sql.Int, studentId],
        by: [sql.Int, createdBy],
        type: [sql.NVarChar(30), type],
        from: [sql.Date, fromDate],
        to: [sql.Date, toDate],
        reason: [sql.NVarChar(500), reason],
      }
    );
    return r[0].id;
  }

  // Only a pending request can be decided; returns false when it already was.
  async decide(id, handledBy, status, comment) {
    const r = await run(
      `UPDATE dbo.Requests SET status = @status, teacherComment = @comment, handledBy = @by, handledAt = SYSUTCDATETIME()
       WHERE id = @id AND status = 'pending'`,
      {
        id: [sql.Int, id],
        by: [sql.Int, handledBy],
        status: [sql.VarChar(10), status],
        comment: [sql.NVarChar(500), comment],
      }
    );
    return r.rowsAffected[0] > 0;
  }
}

module.exports = new RequestDao();
module.exports.RequestDao = RequestDao;
