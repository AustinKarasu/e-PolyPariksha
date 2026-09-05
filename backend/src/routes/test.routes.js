const router = require('express').Router();
const { body, param } = require('express-validator');
const testController = require('../controllers/test.controller');
const { authenticate, requireRole } = require('../middleware/auth.middleware');
const { pdfUpload } = require('../middleware/upload.middleware');
const { validate } = require('../middleware/validate.middleware');

const testValidation = [
  body('title').trim().isLength({ min: 3, max: 200 }).withMessage('Title must be 3 to 200 characters'),
  body('branchId').isInt({ min: 1 }),
  body('semester').isInt({ min: 1, max: 6 }),
  body('scheduledStart').isISO8601(),
  body('scheduledEnd').isISO8601(),
  body('timeLimitMinutes').isInt({ min: 1, max: 360 }),
  body('scheduledEnd').custom((value, { req }) => new Date(value) > new Date(req.body.scheduledStart))
];
const testId = [param('id').isInt({ min: 1 })];

router.get('/', authenticate, testController.listTests);
router.get('/history', authenticate, requireRole('student'), testController.listHistory);
router.get('/:id/admin/pdf', authenticate, requireRole('admin'), testId, validate, testController.downloadAdminPdf);
router.get('/:id/pdf', authenticate, testId, validate, testController.downloadPdf);

router.post(
  '/',
  authenticate,
  requireRole('admin'),
  pdfUpload.single('pdf'),
  testValidation,
  validate,
  testController.createTest
);

router.put(
  '/:id',
  authenticate,
  requireRole('admin'),
  [...testId, ...testValidation, body('isActive').isBoolean()],
  validate,
  testController.updateTest
);

router.patch(
  '/:id/active',
  authenticate,
  requireRole('admin'),
  [...testId, body('isActive').isBoolean()],
  validate,
  testController.setTestActive
);

router.post(
  '/:id/end',
  authenticate,
  requireRole('admin'),
  testId,
  validate,
  testController.endTestNow
);

router.put(
  '/:id/pdf',
  authenticate,
  requireRole('admin'),
  testId,
  validate,
  pdfUpload.single('pdf'),
  testController.replacePdf
);

router.delete('/:id', authenticate, requireRole('admin'), testId, validate, testController.removeTest);

module.exports = router;
