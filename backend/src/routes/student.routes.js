const router = require('express').Router();
const { body } = require('express-validator');
const studentController = require('../controllers/student.controller');
const { authenticate, requireRole } = require('../middleware/auth.middleware');
const { imageUpload } = require('../middleware/upload.middleware');
const { validate } = require('../middleware/validate.middleware');

// Student self-service
router.get('/me', authenticate, requireRole('student'), studentController.getProfile);
router.post('/me/email-otp', authenticate, requireRole('student'), [body('email').isEmail().normalizeEmail()], validate, studentController.requestEmailChangeOtp);
router.patch(
  '/me',
  authenticate,
  requireRole('student'),
  [
    body('phone').optional().trim().isLength({ max: 20 }),
    body('address').optional().trim().isLength({ max: 500 }),
    body('guardianName').optional().trim().isLength({ max: 120 }),
    body('email').optional({ nullable: true, checkFalsy: true }).isEmail().normalizeEmail(),
    body('emailOtpCode').optional({ nullable: true, checkFalsy: true }).trim().isLength({ min: 6, max: 8 })
  ],
  validate,
  studentController.updateProfile
);
router.put(
  '/me/photo',
  authenticate,
  requireRole('student'),
  imageUpload.single('photo'),
  studentController.updatePhoto
);

// Admin endpoints
router.get('/', authenticate, requireRole('admin'), studentController.listStudents);
router.post(
  '/',
  authenticate,
  requireRole('admin'),
  [
    body('fullName').trim().isLength({ min: 2, max: 120 }),
    body('collegeId').trim().isLength({ min: 2, max: 60 }),
    body('password').optional({ nullable: true, checkFalsy: true }).trim().isLength({ min: 4, max: 80 }),
    body('branchId').isInt({ min: 1 }),
    body('email').isEmail().normalizeEmail(),
    body('dob').isISO8601(),
    body('semester').isInt({ min: 1, max: 6 }),
    body('rollNo').trim().isLength({ min: 1, max: 40 }),
    body('boardRollNo').trim().isLength({ min: 2, max: 40 }),
    body('collegeName').trim().isLength({ min: 2, max: 200 }),
    body('courseName').trim().isLength({ min: 2, max: 120 }),
    body('guardianName').trim().isLength({ min: 2, max: 120 }),
    body('phone').trim().isLength({ min: 7, max: 20 }),
    body('address').trim().isLength({ min: 2, max: 500 }),
    body('admissionYear').isInt({ min: 2000, max: 2100 }),
    body('dropoutYear').isInt({ min: 2000, max: 2100 })
  ],
  validate,
  studentController.adminCreateStudent
);
router.get('/:id', authenticate, requireRole('admin'), studentController.getStudentById);
router.patch(
  '/:id',
  authenticate,
  requireRole('admin'),
  [
    body('fullName').optional({ nullable: true, checkFalsy: true }).trim().isLength({ min: 2, max: 120 }),
    body('collegeId').optional({ nullable: true, checkFalsy: true }).trim().isLength({ min: 2, max: 60 }),
    body('email').optional({ nullable: true, checkFalsy: true }).isEmail().normalizeEmail(),
    body('dob').optional({ nullable: true, checkFalsy: true }).isISO8601(),
    body('semester').optional({ nullable: true, checkFalsy: true }).isInt({ min: 1, max: 6 }),
    body('rollNo').optional({ nullable: true, checkFalsy: true }).trim().isLength({ max: 40 }),
    body('boardRollNo').optional({ nullable: true, checkFalsy: true }).trim().isLength({ max: 40 }),
    body('collegeName').optional({ nullable: true, checkFalsy: true }).trim().isLength({ max: 200 }),
    body('courseName').optional({ nullable: true, checkFalsy: true }).trim().isLength({ max: 120 }),
    body('guardianName').optional({ nullable: true, checkFalsy: true }).trim().isLength({ max: 120 }),
    body('phone').optional({ nullable: true, checkFalsy: true }).trim().isLength({ max: 20 }),
    body('address').optional({ nullable: true, checkFalsy: true }).trim().isLength({ max: 500 }),
    body('admissionYear').optional({ nullable: true, checkFalsy: true }).isInt({ min: 2000, max: 2100 }),
    body('dropoutYear').optional({ nullable: true, checkFalsy: true }).isInt({ min: 2000, max: 2100 }),
    body('branchId').optional({ nullable: true, checkFalsy: true }).isInt({ min: 1 }),
    body('isActive').optional({ nullable: true }).isBoolean(),
    body('password').optional({ nullable: true, checkFalsy: true }).trim().isLength({ min: 4, max: 80 })
  ],
  validate,
  studentController.adminUpdateStudent
);
router.put(
  '/:id/photo',
  authenticate,
  requireRole('admin'),
  imageUpload.single('photo'),
  studentController.adminUpdateStudentPhoto
);
router.delete('/:id', authenticate, requireRole('admin'), studentController.adminDeleteStudent);

module.exports = router;
