const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const userDao = require('../dao/UserDao');

const MAX_IDENTIFIER = 150;
const MAX_PASSWORD = 72; // bcrypt limit
const JWT_EXPIRES_IN = '1h';

const isStr = (v) => typeof v === 'string';

function normalizeIdentifier(raw) {
  const s = raw.trim();
  return s.includes('@') ? s.toLowerCase() : s;
}

function publicUser(u) {
  return { id: u.id, name: u.name, email: u.email, phone: u.phone, role: u.role };
}

// Valid bcrypt hash used to equalize timing when the user does not exist.
const DUMMY_HASH = bcrypt.hashSync('dummy-password-for-timing', 10);

class AuthController {
  constructor(dao = userDao) {
    this.dao = dao;
    this.login = this.login.bind(this);
    this.resetPassword = this.resetPassword.bind(this);
    this.me = this.me.bind(this);
  }

  async login(req, res, next) {
    try {
      const { identifier, password } = req.body || {};
      if (!isStr(identifier) || !isStr(password) || identifier.trim() === '' || password === '') {
        return res.status(400).json({ message: 'identifier and password are required' });
      }
      const id = normalizeIdentifier(identifier);
      const invalid = () => res.status(401).json({ message: 'Invalid credentials' });
      if (id.length > MAX_IDENTIFIER || password.length > 256) {
        await bcrypt.compare(password.slice(0, 72), DUMMY_HASH);
        return invalid();
      }
      const user = await this.dao.findByIdentifier(id);
      const ok = await bcrypt.compare(password, user ? user.passwordHash : DUMMY_HASH);
      if (!user || !ok) return invalid();

      const token = jwt.sign({ sub: user.id, role: user.role }, process.env.JWT_SECRET, {
        expiresIn: JWT_EXPIRES_IN,
      });
      return res.status(200).json({ token, user: publicUser(user) });
    } catch (e) {
      next(e);
    }
  }

  async resetPassword(req, res, next) {
    try {
      const { identifier, newPassword } = req.body || {};
      if (!isStr(identifier) || identifier.trim() === '') {
        return res.status(400).json({ message: 'identifier is required' });
      }
      if (!isStr(newPassword) || newPassword.length < 6) {
        return res.status(400).json({ message: 'newPassword must be at least 6 characters' });
      }
      if (newPassword.length > MAX_PASSWORD) {
        return res
          .status(400)
          .json({ message: `newPassword must be at most ${MAX_PASSWORD} characters` });
      }
      const id = normalizeIdentifier(identifier);
      const user = id.length > MAX_IDENTIFIER ? null : await this.dao.findByIdentifier(id);
      if (!user) return res.status(404).json({ message: 'User not found' });
      const hash = await bcrypt.hash(newPassword, 10);
      await this.dao.updatePasswordHash(user.id, hash);
      return res.status(200).json({ message: 'Password updated' });
    } catch (e) {
      next(e);
    }
  }

  async me(req, res, next) {
    try {
      const user = await this.dao.findById(req.auth.sub);
      if (!user) return res.status(401).json({ message: 'Invalid token' });
      return res.status(200).json(publicUser(user));
    } catch (e) {
      next(e);
    }
  }
}

module.exports = AuthController;
