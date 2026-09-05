const adminService = require('../services/admin.service');
const appErrorService = require('../services/app-error.service');

async function listAdmins(req, res, next) {
  try {
    const admins = await adminService.listAdmins(req.user.sub);
    res.json({ admins });
  } catch (err) {
    next(err);
  }
}

async function listApplications(req, res, next) {
  try {
    const applications = await adminService.listApplications(req.user.sub);
    res.json({ applications });
  } catch (err) {
    next(err);
  }
}

async function analytics(req, res, next) {
  try {
    const analytics = await appErrorService.analyticsSummary(req.user);
    res.json({ analytics });
  } catch (err) {
    next(err);
  }
}

async function appErrors(req, res, next) {
  try {
    const reports = await appErrorService.listAppErrors(req.user, {
      limit: req.query.limit
    });
    res.json({ reports });
  } catch (err) {
    next(err);
  }
}

async function createAdmin(req, res, next) {
  try {
    const admin = await adminService.createAdmin(req.body, req.user.sub);
    res.status(201).json({ admin });
  } catch (err) {
    next(err);
  }
}

async function requestCreateAdminOtp(req, res, next) {
  try {
    res.json(await adminService.requestCreateAdminOtp(req.user.sub));
  } catch (err) {
    next(err);
  }
}

async function notifyAppUpdate(req, res, next) {
  try {
    res.json(await adminService.notifyAppUpdate(req.body.version, req.user.sub));
  } catch (err) {
    next(err);
  }
}

async function approveApplication(req, res, next) {
  try {
    const admin = await adminService.approveApplication(Number(req.params.id), req.user.sub);
    res.status(201).json({ admin });
  } catch (err) {
    next(err);
  }
}

async function rejectApplication(req, res, next) {
  try {
    await adminService.rejectApplication(Number(req.params.id), req.user.sub);
    res.json({ status: 'rejected' });
  } catch (err) {
    next(err);
  }
}

async function deleteApplication(req, res, next) {
  try {
    await adminService.deleteApplication(Number(req.params.id), req.user.sub);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
}

async function setAdminActive(req, res, next) {
  try {
    await adminService.setAdminActive(
      Number(req.params.id),
      Boolean(req.body.isActive),
      req.user.sub
    );
    res.json({ status: 'updated' });
  } catch (err) {
    next(err);
  }
}

async function setPrimaryAdmin(req, res, next) {
  try {
    await adminService.setPrimaryAdmin(Number(req.params.id), req.user.sub, req.body.otpCode);
    res.json({ status: 'updated' });
  } catch (err) {
    next(err);
  }
}

async function updateAdmin(req, res, next) {
  try {
    const admin = await adminService.updateAdmin(Number(req.params.id), req.body, req.user.sub);
    res.json({ admin });
  } catch (err) {
    next(err);
  }
}

async function deleteAdmin(req, res, next) {
  try {
    await adminService.deleteAdmin(Number(req.params.id), req.user.sub);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
}

async function clearData(req, res, next) {
  try {
    await adminService.clearData(req.user.sub, req.body);
    res.json({ status: 'cleared' });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  listAdmins,
  listApplications,
  analytics,
  appErrors,
  createAdmin,
  requestCreateAdminOtp,
  notifyAppUpdate,
  approveApplication,
  rejectApplication,
  deleteApplication,
  updateAdmin,
  setAdminActive,
  setPrimaryAdmin,
  deleteAdmin,
  clearData
};
