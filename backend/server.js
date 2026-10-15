require('dotenv').config({ path: require('path').join(__dirname, '.env') });
const express = require('express');
const cors = require('cors');
const AuthController = require('./controllers/AuthController');
const { requireAuth } = require('./middleware/auth');

const app = express();
const auth = new AuthController();

app.disable('x-powered-by');
app.use(cors());
app.use(express.json({ limit: '100kb' }));

app.get('/api/health', (req, res) => res.status(200).json({ status: 'ok' }));
app.post('/api/login', auth.login);
app.post('/api/reset-password', auth.resetPassword);
app.get('/api/me', requireAuth, auth.me);

app.use((req, res) => res.status(404).json({ message: 'Not found' }));

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  if (err && err.type === 'entity.parse.failed') {
    return res.status(400).json({ message: 'Malformed JSON' });
  }
  if (err && err.type === 'entity.too.large') {
    return res.status(413).json({ message: 'Payload too large' });
  }
  console.error('Unhandled error:', err && err.message);
  res.status(500).json({ message: 'Internal server error' });
});

if (require.main === module) {
  const port = parseInt(process.env.PORT || '3000', 10);
  app.listen(port, '0.0.0.0', () => console.log(`API listening on 0.0.0.0:${port}`));
}

module.exports = app;
