const attemptService = require('../services/attempt.service');

async function startAttempt(req, res, next) {
  try {
    const attempt = await attemptService.startAttempt(Number(req.params.testId), req.user, requestContext(req));
    res.status(201).json({ attempt });
  } catch (err) {
    next(err);
  }
}

async function completeAttempt(req, res, next) {
  try {
    await attemptService.completeAttempt(
      Number(req.params.testId),
      req.user,
      req.body.answerNote,
      requestContext(req)
    );
    res.json({ status: 'completed' });
  } catch (err) {
    next(err);
  }
}

async function recordEvent(req, res, next) {
  try {
    const result = await attemptService.recordStudentEvent(
      Number(req.params.testId),
      req.user,
      req.body.eventType,
      req.body.metadata || {},
      requestContext(req)
    );
    res.json(result);
  } catch (err) {
    next(err);
  }
}

async function listEvents(req, res, next) {
  try {
    const events = await attemptService.listEvents(req.query, req.user);
    res.json({ events });
  } catch (err) {
    next(err);
  }
}

async function listLocked(req, res, next) {
  try {
    const attempts = await attemptService.listLockedAttempts(req.query, req.user);
    res.json({ attempts });
  } catch (err) {
    next(err);
  }
}

async function allowAttempt(req, res, next) {
  try {
    await attemptService.allowAttempt(Number(req.params.attemptId), req.user, requestContext(req));
    res.json({ status: 'admin_allowed' });
  } catch (err) {
    next(err);
  }
}

function requestContext(req) {
  return {
    ipAddress: req.ip,
    userAgent: req.get('user-agent')
  };
}

module.exports = {
  startAttempt,
  completeAttempt,
  recordEvent,
  listEvents,
  listLocked,
  allowAttempt
};
