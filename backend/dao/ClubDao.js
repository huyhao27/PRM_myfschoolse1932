const { sql, query, run } = require('../db');

const MEMBER_COUNT = `c.baseMembers + (SELECT COUNT(*) FROM dbo.ClubMembers m WHERE m.clubId = c.id AND m.status = 'approved')`;

class ClubDao {
  list(userId, q) {
    // Escape LIKE wildcards so the search text is matched literally.
    const pattern = `%${(q || '').replace(/[[%_]/g, '[$&]')}%`;
    return query(
      `SELECT c.id, c.name, c.icon, ${MEMBER_COUNT} AS memberCount, my.status AS myStatus
       FROM dbo.Clubs c LEFT JOIN dbo.ClubMembers my ON my.clubId = c.id AND my.userId = @uid
       WHERE c.name LIKE @q ORDER BY c.name`,
      { uid: [sql.Int, userId], q: [sql.NVarChar(120), pattern] }
    );
  }

  async findById(userId, id) {
    const rows = await query(
      `SELECT c.id, c.name, c.icon, c.description, c.meeting, c.location, c.advisor, c.president,
              ${MEMBER_COUNT} AS memberCount, my.status AS myStatus
       FROM dbo.Clubs c LEFT JOIN dbo.ClubMembers my ON my.clubId = c.id AND my.userId = @uid
       WHERE c.id = @id`,
      { uid: [sql.Int, userId], id: [sql.Int, id] }
    );
    return rows[0] || null;
  }

  members(clubId, limit = 3) {
    return query(
      `SELECT TOP (@n) u.name FROM dbo.ClubMembers m JOIN dbo.Users u ON u.id = m.userId
       WHERE m.clubId = @id AND m.status = 'approved' ORDER BY m.joinedAt`,
      { id: [sql.Int, clubId], n: [sql.Int, limit] }
    );
  }

  // Returns false when the user already has a membership row for the club.
  async join(clubId, userId) {
    const r = await run(
      `IF NOT EXISTS (SELECT 1 FROM dbo.ClubMembers WHERE clubId = @c AND userId = @u)
         INSERT dbo.ClubMembers (clubId, userId, status) VALUES (@c, @u, 'pending')`,
      { c: [sql.Int, clubId], u: [sql.Int, userId] }
    );
    return r.rowsAffected.reduce((a, b) => a + b, 0) > 0;
  }
}

module.exports = new ClubDao();
module.exports.ClubDao = ClubDao;
