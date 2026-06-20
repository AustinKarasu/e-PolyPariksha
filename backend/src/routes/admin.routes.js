const router = require('express').Router();
const { body, param } = require('express-validator');
const adminController = require('../controllers/admin.controller');
const { authenticate, requireRole } = require('../middleware/auth.middleware');
const { validate } = require('../middleware/validate.middleware');

router.use(authenticate, requireRole('admin'));

router.get('/', adminController.listAdmins);
router.get('/applications', adminController.listApplications);
router.post('/request-create-otp', adminController.requestCreateAdminOtp);
router.post('/app-update', [body('version').trim().isLength({ min: 1, max: 40 })], validate, adminController.notifyAppUpdate);
const adminId = [param('id').isInt({ min: 1 })];
router.post('/applications/:id/approve', adminId, validate, adminController.approveApplication);
router.post('/applications/:id/reject', adminId, validate, adminController.rejectApplication);
router.delete('/applications/:id', adminId, validate, adminController.deleteApplication);
router.post(
  '/',
  [
    body('fullName').trim().isLength({ min: 2, max: 120 }),
    body('email').isEmail().normalizeEmail(),
    body('password').isStrongPassword({
      minLength: 10,
      minLowercase: 1,
      minUppercase: 1,
      minNumbers: 1,
      minSymbols: 1
    }),
    body('otpCode').trim().isLength({ min: 6, max: 8 })
  ],
  validate,
  adminController.createAdmin
);
router.patch(
  '/:id',
  [
    ...adminId,
    body('fullName').optional().trim().isLength({ min: 2, max: 120 }),
    body('email').optional().isEmail().normalizeEmail(),
    body('password').optional({ nullable: true, checkFalsy: true }).isStrongPassword({
      minLength: 10,
      minLowercase: 1,
      minUppercase: 1,
      minNumbers: 1,
      minSymbols: 1
    }),
    body('isActive').optional().isBoolean()
    ,body('emailOtpCode').optional({ nullable: true, checkFalsy: true }).trim().isLength({ min: 6, max: 8 })
  ],
  validate,
  adminController.updateAdmin
);
router.patch(
  '/:id/active',
  [...adminId, body('isActive').isBoolean()],
  validate,
  adminController.setAdminActive
);
router.patch(
  '/:id/primary',
  [...adminId, body('otpCode').optional({ nullable: true, checkFalsy: true }).trim().isLength({ min: 6, max: 8 })],
  validate,
  adminController.setPrimaryAdmin
);
router.delete('/:id', adminId, validate, adminController.deleteAdmin);
router.post(
  '/clear-data',
  [
    body('totpCode').trim().isLength({ min: 6, max: 8 }),
    body('tests').optional().isBoolean(),
    body('history').optional().isBoolean(),
    body('students').optional().isBoolean(),
    body('sessions').optional().isBoolean(),
    body('logs').optional().isBoolean(),
    body('applications').optional().isBoolean()
  ],
  validate,
  adminController.clearData
);

module.exports = router;
