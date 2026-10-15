// npm run db:init : applies schema.sql then seeds demo users (idempotent).
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const { closePool } = require('../db');
const userDao = require('../dao/UserDao');

const SEED = [
  { name: 'Giao vien Demo', email: 'gv@fschool.vn', phone: null, role: 'GV' },
  { name: 'Quan ly Demo', email: 'manager@fschool.vn', phone: null, role: 'Manager' },
  { name: 'Phu huynh Demo', email: 'ph@fschool.vn', phone: '0901234567', role: 'PH' },
  { name: 'Hoc sinh Demo', email: 'hs@fschool.vn', phone: null, role: 'HS' },
];

(async () => {
  try {
    const script = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
    for (const batch of script.split(/^\s*GO\s*$/im)) {
      if (batch.trim()) await userDao.runBatch(batch);
    }
    console.log('Schema applied.');
    const passwordHash = await bcrypt.hash('123456', 10);
    for (const u of SEED) await userDao.insertSeedIfMissing({ ...u, passwordHash });
    console.log('Seed applied (demo password: 123456).');
  } catch (e) {
    console.error('db:init failed:', e.message);
    process.exitCode = 1;
  } finally {
    await closePool();
  }
})();
