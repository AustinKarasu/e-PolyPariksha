const { validationResult } = require('express-validator');
const { ApiError } = require('../utils/api-error');

function validate(req, _res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    // Never reflect rejected values (especially passwords, tokens, or HTML) back to clients.
    const details = errors.array().map(({ type, path, location, msg }) => ({ type, path, location, msg }));
    const fields = [...new Set(details.map((error) => error.path || error.param).filter(Boolean))];
    const message = fields.length > 0
      ? `Validation failed: ${fields.join(', ')}`
      : 'Validation failed';
    return next(new ApiError(422, message, details));
  }
  return next();
}

module.exports = { validate };
