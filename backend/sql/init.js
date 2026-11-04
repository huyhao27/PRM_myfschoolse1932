// npm run db:init : applies schema.sql then seeds demo users (idempotent).
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const { closePool } = require('../db');
const userDao = require('../dao/UserDao');

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
  for (const batch of script.split(/^\s*GO\s*$/im)) {
    if (batch.trim()) await userDao.runBatch(batch);
  }
}

(async () => {
  try {
    await runScript('schema.sql');
    console.log('Schema applied.');
    const passwordHash = await bcrypt.hash('123456', 10);
    for (const u of SEED) {
      await userDao.insertSeedIfMissing({ ...u, passwordHash });
      await userDao.setPhoneIfMissing(u.email, u.phone);
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
