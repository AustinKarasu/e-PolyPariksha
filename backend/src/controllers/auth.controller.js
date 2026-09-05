const authService = require('../services/auth.service');

async function login(req, res, next) {
  try {
    const result = await authService.login(req.body.identifier, req.body.password, {
      deviceLabel: req.body.deviceLabel,
      totpCode: req.body.totpCode,
      emailOtpCode: req.body.emailOtpCode,
      ipAddress: req.ip,
      userAgent: req.get('user-agent')
    });
    res.json(result);
  } catch (err) {
    next(err);
  }
}

async function me(req, res, next) {
  try {
    const user = await authService.getCurrentUser(req.user.sub);
    res.json({ user });
  } catch (err) {
    next(err);
  }
}

async function registerAdmin(req, res, next) {
  try {
    const admin = await authService.registerAdmin(req.body);
    res.status(201).json({ admin });
  } catch (err) {
    next(err);
  }
}

async function requestAdminRegistrationOtp(req, res, next) {
  try {
    const result = await authService.requestAdminRegistrationOtp(req.body.email);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

async function requestEmailChangeOtp(req, res, next) {
  try {
    res.json(await authService.requestEmailChangeOtp(req.user.sub, req.body.email));
  } catch (err) {
    next(err);
  }
}
async function requestInitialCredentialsOtp(req, res, next) { try { res.json(await authService.requestInitialCredentialsOtp(req.user.sub, req.body.email)); } catch (err) { next(err); } }
async function completeInitialCredentials(req, res, next) { try { res.json({ user: await authService.completeInitialCredentials(req.user.sub, req.body) }); } catch (err) { next(err); } }

async function requestPasswordChangeOtp(req, res, next) {
  try { res.json(await authService.requestPasswordChangeOtp(req.user.sub)); } catch (err) { next(err); }
}

async function requestPasswordReset(req, res, next) {
  try { res.json(await authService.requestPasswordReset(req.body.email, req.body.role)); } catch (err) { next(err); }
}

async function verifyPasswordReset(req, res, next) {
  try { res.json(await authService.verifyPasswordReset(req.body.email, req.body.role, req.body.otpCode)); } catch (err) { next(err); }
}

async function completePasswordReset(req, res, next) {
  try {
    await authService.completePasswordReset(req.body.resetToken, req.body.newPassword);
    res.status(204).send();
  } catch (err) { next(err); }
}

async function updateMe(req, res, next) {
  try {
    const user = await authService.updateCurrentUser(req.user.sub, req.body);
    res.json({ user });
  } catch (err) {
    next(err);
  }
}

async function updateMyPhoto(req, res, next) {
  try {
    const user = await authService.updateCurrentUserPhoto(req.user.sub, req.file);
    res.json({ user });
  } catch (err) {
    next(err);
  }
}

async function changePassword(req, res, next) {
  try {
    await authService.changeCurrentUserPassword(req.user.sub, {
      newPassword: req.body.newPassword,
      totpCode: req.body.totpCode,
      emailOtpCode: req.body.emailOtpCode
    });
    res.status(204).send();
  } catch (err) {
    next(err);
  }
}

async function setupTwoFactor(req, res, next) {
  try {
    const result = await authService.setupTwoFactor(req.user.sub);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

async function enableTwoFactor(req, res, next) {
  try {
    const user = await authService.enableTwoFactor(req.user.sub, req.body.code);
    res.json({ user });
  } catch (err) {
    next(err);
  }
}

async function disableTwoFactor(req, res, next) {
  try {
    const user = await authService.disableTwoFactor(req.user.sub, req.body.code);
    res.json({ user });
  } catch (err) {
    next(err);
  }
}

async function logout(req, res, next) {
  try {
    await authService.logout(req.user);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
}

module.exports = {
  login,
  requestAdminRegistrationOtp,
  requestEmailChangeOtp,
  requestInitialCredentialsOtp,
  completeInitialCredentials,
  requestPasswordChangeOtp,
  requestPasswordReset,
  verifyPasswordReset,
  completePasswordReset,
  registerAdmin,
  me,
  updateMe,
  updateMyPhoto,
  changePassword,
  setupTwoFactor,
  enableTwoFactor,
  disableTwoFactor,
  logout
};
