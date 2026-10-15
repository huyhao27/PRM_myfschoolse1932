const jwt = require('jsonwebtoken');

function requireAuth(req, res, next) {
  const h = req.headers.authorization || '';
  const m = /^Bearer\s+(\S+)$/i.exec(h);
  if (!m) return res.status(401).json({ message: 'Missing or malformed Authorization header' });
  try {
    const payload = jwt.verify(m[1], process.env.JWT_SECRET, { algorithms: ['HS256'] });
    if (!Number.isInteger(payload.sub)) throw new Error('bad sub');
    req.auth = payload;
    next();
  } catch (e) {
    const msg = e.name === 'TokenExpiredError' ? 'Token expired' : 'Invalid token';
    res.status(401).json({ message: msg });
  }
}

module.exports = { requireAuth };
