const appErrorService = require('../services/app-error.service');

async function record(req, res, next) {
  try {
    const report = await appErrorService.recordAppError(req.user, req.body);
    res.status(201).json({ report });
  } catch (err) {
    next(err);
  }
}

module.exports = { record };
