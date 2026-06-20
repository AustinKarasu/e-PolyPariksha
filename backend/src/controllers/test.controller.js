const testService = require('../services/test.service');

async function createTest(req, res, next) {
  try {
    const test = await testService.createTest({
      title: req.body.title,
      branchId: Number(req.body.branchId),
      semester: Number(req.body.semester),
      scheduledStart: req.body.scheduledStart,
      scheduledEnd: req.body.scheduledEnd,
      timeLimitMinutes: Number(req.body.timeLimitMinutes),
      file: req.file,
      createdBy: req.user.sub
    });
    res.status(201).json({ test });
  } catch (err) {
    next(err);
  }
}

async function listTests(req, res, next) {
  try {
    const tests = req.user.role === 'admin'
      ? await testService.listAdminTests(req.user.sub)
      : await testService.listStudentTests(req.user);
    res.json({ tests });
  } catch (err) {
    next(err);
  }
}

async function listHistory(req, res, next) {
  try {
    const tests = await testService.listStudentHistory(req.user);
    res.json({ tests });
  } catch (err) {
    next(err);
  }
}

async function updateTest(req, res, next) {
  try {
    const test = await testService.updateTest(Number(req.params.id), {
      title: req.body.title,
      branchId: Number(req.body.branchId),
      semester: Number(req.body.semester),
      scheduledStart: req.body.scheduledStart,
      scheduledEnd: req.body.scheduledEnd,
      timeLimitMinutes: Number(req.body.timeLimitMinutes),
      isActive: Boolean(req.body.isActive)
    }, req.user.sub);
    res.json({ test });
  } catch (err) {
    next(err);
  }
}

async function setTestActive(req, res, next) {
  try {
    const test = await testService.setTestActive(Number(req.params.id), req.body.isActive === true, req.user.sub);
    res.json({ test });
  } catch (err) {
    next(err);
  }
}

async function endTestNow(req, res, next) {
  try {
    const test = await testService.endTestNow(Number(req.params.id), req.user.sub);
    res.json({ test });
  } catch (err) {
    next(err);
  }
}

async function replacePdf(req, res, next) {
  try {
    const test = await testService.replacePdf(Number(req.params.id), req.file, req.user.sub);
    res.json({ test });
  } catch (err) {
    next(err);
  }
}

async function removeTest(req, res, next) {
  try {
    const test = await testService.removeTest(Number(req.params.id), req.user.sub);
    res.json({ test, message: 'Test cancelled and eligible users have been notified.' });
  } catch (err) {
    next(err);
  }
}

async function downloadPdf(req, res, next) {
  try {
    const delivery = req.user.role === 'admin'
      ? await testService.getAdminPdf(Number(req.params.id), req.user.sub)
      : await testService.getStudentPdf(Number(req.params.id), req.user, {
          ipAddress: req.ip,
          userAgent: req.get('user-agent')
        });
    return sendPdfDelivery(res, delivery);
  } catch (err) {
    next(err);
  }
}

async function downloadAdminPdf(req, res, next) {
  try {
    const delivery = await testService.getAdminPdf(Number(req.params.id), req.user.sub);
    return sendPdfDelivery(res, delivery);
  } catch (err) {
    next(err);
  }
}

function sendPdfDelivery(res, delivery) {
  if (delivery.type === 'redirect') {
    return res.redirect(delivery.value);
  }
  if (delivery.type === 'buffer') {
    res.setHeader('Content-Type', delivery.contentType || 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename="${safeDownloadName(delivery.filename)}"`);
    res.setHeader('Content-Length', delivery.value.length);
    return res.send(delivery.value);
  }
  return res.download(delivery.value);
}

function safeDownloadName(name) {
  return String(name || 'question-paper.pdf').replace(/["\r\n]/g, '_');
}

module.exports = {
  createTest,
  listTests,
  listHistory,
  updateTest,
  setTestActive,
  endTestNow,
  replacePdf,
  removeTest,
  downloadPdf,
  downloadAdminPdf
};
