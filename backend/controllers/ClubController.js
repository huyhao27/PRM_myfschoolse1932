const clubDao = require('../dao/ClubDao');
const { HttpError, parseId } = require('../lib/http');

async function list(req, res) {
  const q = typeof req.query.q === 'string' ? req.query.q.trim().slice(0, 50) : '';
  res.json(await clubDao.list(req.user.id, q));
}

async function detail(req, res) {
  const club = await clubDao.findById(req.user.id, parseId(req.params.id));
  if (!club) throw new HttpError(404, 'Club not found');
  const members = await clubDao.members(club.id, 3);
  res.json({ ...club, memberPreview: members.map((m) => m.name) });
}

// Students ask to join; the membership starts as "pending".
async function join(req, res) {
  const id = parseId(req.params.id);
  if (!(await clubDao.findById(req.user.id, id))) throw new HttpError(404, 'Club not found');
  if (!(await clubDao.join(id, req.user.id))) throw new HttpError(409, 'You already joined or requested this club');
  res.status(201).json({ status: 'pending' });
}

module.exports = { list, detail, join };
