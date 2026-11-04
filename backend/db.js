require('dotenv').config({ path: require('path').join(__dirname, '.env') });
const sql = require('mssql');

const config = {
  server: process.env.DB_SERVER || 'localhost',
  port: parseInt(process.env.DB_PORT || '1433', 10),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  options: { encrypt: false, trustServerCertificate: true },
  pool: { max: 10, min: 0, idleTimeoutMillis: 30000 },
};

let poolPromise = null;

function getPool() {
  if (!poolPromise) {
    poolPromise = new sql.ConnectionPool(config)
      .connect()
      .catch((err) => {
        poolPromise = null;
        throw err;
      });
  }
  return poolPromise;
}

async function closePool() {
  if (poolPromise) {
    const p = await poolPromise;
    poolPromise = null;
    await p.close();
  }
}

// Parameterized query helper. params: { name: [sql.Type, value] }. Returns the full mssql result.
async function run(text, params = {}) {
  const req = (await getPool()).request();
  for (const [name, [type, value]] of Object.entries(params)) req.input(name, type, value);
  return req.query(text);
}

async function query(text, params = {}) {
  return (await run(text, params)).recordset;
}

module.exports = { sql, getPool, closePool, run, query };
