// Who may see which students. All visibility rules live here so every module applies the same ones.
const { sql, query } = require('../db');

// SQL condition on a Users row (alias) saying "this student is visible to @uid".
function studentScope(role, alias = 's') {
  switch (role) {
    case 'HS':
      return `${alias}.id = @uid`;
    case 'PH':
      return `${alias}.id IN (SELECT studentId FROM dbo.ParentStudent WHERE parentId = @uid)`;
    case 'GV':
      return `${alias}.role = 'HS' AND ${alias}.className IN (SELECT className FROM dbo.Schedule WHERE teacherId = @uid)`;
    case 'Manager':
      return `${alias}.role = 'HS'`;
    default:
      return '1 = 0';
  }
}

class AccessDao {
  studentScope(role, alias) {
    return studentScope(role, alias);
  }

  async visibleStudents(user) {
    return query(
      `SELECT s.id, s.name, s.className FROM dbo.Users s WHERE ${studentScope(user.role)} ORDER BY s.name`,
      { uid: [sql.Int, user.id] }
    );
  }
}

module.exports = new AccessDao();
module.exports.AccessDao = AccessDao;
