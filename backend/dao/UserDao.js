// Repository for Users. All SQL for users lives here.
const { sql, getPool } = require('../db');

const PUBLIC_COLS = 'id, name, email, phone, role';

class UserDao {
  // identifier = email or phone (already normalized by caller). Returns row incl. passwordHash.
  async findByIdentifier(identifier) {
    const pool = await getPool();
    const r = await pool
      .request()
      .input('id', sql.NVarChar(150), identifier)
      .query(
        `SELECT TOP 1 ${PUBLIC_COLS}, passwordHash FROM dbo.Users WHERE email = @id OR phone = @id`
      );
    return r.recordset[0] || null;
  }

  async findById(id) {
    const pool = await getPool();
    const r = await pool
      .request()
      .input('id', sql.Int, id)
      .query(`SELECT ${PUBLIC_COLS} FROM dbo.Users WHERE id = @id`);
    return r.recordset[0] || null;
  }

  async updatePasswordHash(id, passwordHash) {
    const pool = await getPool();
    const r = await pool
      .request()
      .input('id', sql.Int, id)
      .input('hash', sql.NVarChar(100), passwordHash)
      .query('UPDATE dbo.Users SET passwordHash = @hash WHERE id = @id');
    return r.rowsAffected[0] > 0;
  }

  // Idempotent: inserts only if no user with that email exists.
  async insertSeedIfMissing({ name, email, phone, passwordHash, role }) {
    const pool = await getPool();
    await pool
      .request()
      .input('name', sql.NVarChar(100), name)
      .input('email', sql.NVarChar(150), email)
      .input('phone', sql.VarChar(20), phone)
      .input('hash', sql.NVarChar(100), passwordHash)
      .input('role', sql.VarChar(10), role)
      .query(
        `IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE email = @email)
           INSERT INTO dbo.Users (name, email, phone, passwordHash, role)
           VALUES (@name, @email, @phone, @hash, @role)`
      );
  }

  // Runs a schema batch (DDL). Kept here so all SQL stays in the DAO layer.
  async runBatch(batchText) {
    const pool = await getPool();
    await pool.request().batch(batchText);
  }
}

module.exports = new UserDao();
module.exports.UserDao = UserDao;
