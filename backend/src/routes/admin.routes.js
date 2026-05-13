const router = require('express').Router();
const { body } = require('express-validator');
const adminController = require('../controllers/admin.controller');
const { authenticate, requireRole } = require('../middleware/auth.middleware');
const { validate } = require('../middleware/validate.middleware');

router.use(authenticate, requireRole('admin'));

router.get('/', adminController.listAdmins);
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
    })
  ],
  validate,
  adminController.createAdmin
);
router.patch(
  '/:id',
  [
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
  ],
  validate,
  adminController.updateAdmin
);
router.patch(
  '/:id/active',
  [body('isActive').isBoolean()],
  validate,
  adminController.setAdminActive
);
router.patch('/:id/primary', adminController.setPrimaryAdmin);
router.delete('/:id', adminController.deleteAdmin);
router.post(
  '/clear-data',
  [
    body('totpCode').trim().isLength({ min: 6, max: 8 }),
    body('tests').optional().isBoolean(),
    body('history').optional().isBoolean(),
    body('students').optional().isBoolean(),
    body('sessions').optional().isBoolean()
  ],
  validate,
  adminController.clearData
);

module.exports = router;
