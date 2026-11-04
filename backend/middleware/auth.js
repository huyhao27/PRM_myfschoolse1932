const jwt = require('jsonwebtoken');
const userDao = require('../dao/UserDao');
const { HttpError } = require('../lib/http');

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

// Loads the current user (role comes from the database, not from the token) into req.user.
async function loadUser(req, res, next) {
  const user = await userDao.findProfile(req.auth.sub);
  if (!user) return res.status(401).json({ message: 'Invalid token' });
  req.user = user;
  next();
}

const requireRole = (...roles) => (req, res, next) =>
  roles.includes(req.user.role) ? next() : next(new HttpError(403, 'Forbidden for your role'));

module.exports = { requireAuth, loadUser, requireRole };
