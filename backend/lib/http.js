// Small helpers shared by controllers.
class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

// Positive integer from a URL/query value, or an HttpError(400).
function parseId(raw, name = 'id') {
  if (typeof raw !== 'string' || !/^\d{1,9}$/.test(raw) || Number(raw) < 1) {
    throw new HttpError(400, `${name} must be a positive integer`);
  }
  return Number(raw);
}

// 'YYYY-MM-DD' that is a real calendar date, else null.
function parseDate(raw) {
  if (typeof raw !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(raw)) return null;
  const d = new Date(`${raw}T00:00:00Z`);
  return Number.isNaN(d.getTime()) || d.toISOString().slice(0, 10) !== raw ? null : raw;
}

module.exports = { HttpError, parseId, parseDate };
