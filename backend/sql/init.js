// npm run db:init : applies schema.sql then seeds demo users and demo data (idempotent).
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const { sql, getPool, run, closePool } = require('../db');

const SEED = [
  { name: 'Giao vien Demo', email: 'gv@fschool.vn', phone: '0901000001', role: 'GV' },
  { name: 'Quan ly Demo', email: 'manager@fschool.vn', phone: '0901000002', role: 'Manager' },
  { name: 'Phu huynh Demo', email: 'ph@fschool.vn', phone: '0901234567', role: 'PH' },
  { name: 'Hoc sinh Demo', email: 'hs@fschool.vn', phone: '0901000003', role: 'HS' },
  { name: 'Hoc sinh Mai', email: 'hs2@fschool.vn', phone: '0901000004', role: 'HS' },
  { name: 'Giao vien Lan', email: 'gv2@fschool.vn', phone: '0901000005', role: 'GV' },
];

async function runScript(file) {
  const script = fs.readFileSync(path.join(__dirname, file), 'utf8');
  const pool = await getPool();
  for (const batch of script.split(/^\s*GO\s*$/im)) {
    if (batch.trim()) await pool.request().batch(batch);
  }
}

(async () => {
  try {
    await runScript('schema.sql');
    console.log('Schema applied.');
    const hash = await bcrypt.hash('123456', 10);
    for (const u of SEED) {
      await run(
        `IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE email = @email)
           INSERT INTO dbo.Users (name, email, phone, passwordHash, role) VALUES (@name, @email, @phone, @hash, @role)
         UPDATE dbo.Users SET phone = @phone WHERE email = @email AND phone IS NULL`,
        {
          name: [sql.NVarChar(100), u.name],
          email: [sql.NVarChar(150), u.email],
          phone: [sql.VarChar(20), u.phone],
          hash: [sql.NVarChar(100), hash],
          role: [sql.VarChar(10), u.role],
        }
      );
    }
    console.log('Seed users applied (demo password: 123456).');
    await runScript('seed.sql');
    console.log('Demo data applied (schedule, grades, requests, clubs).');
  } catch (e) {
    console.error('db:init failed:', e.message);
    process.exitCode = 1;
  } finally {
    await closePool();
  }
})();
