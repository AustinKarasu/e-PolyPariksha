const router = require('express').Router();
const { body, param, query } = require('express-validator');
const attemptController = require('../controllers/attempt.controller');
const { authenticate, requireRole } = require('../middleware/auth.middleware');
const { validate } = require('../middleware/validate.middleware');

router.post(
  '/:testId/start',
  authenticate,
  requireRole('student'),
  [param('testId').isInt({ min: 1 })], validate,
  attemptController.startAttempt
);

router.post(
  '/:testId/events',
  authenticate,
  requireRole('student'),
  [
    param('testId').isInt({ min: 1 }),
    body('eventType').isIn([
      'test_list_opened',
      'pdf_opened',
      'app_inactive',
      'app_backgrounded',
      'app_resumed',
      'app_detached',
      'app_hidden',
      'back_blocked',
      'back_navigation_attempt',
      'home_navigation_attempt',
      'split_screen_attempt',
      'picture_in_picture_attempt',
      'split_screen_detected',
      'picture_in_picture_detected',
      'window_focus_lost',
      'exam_heartbeat',
      'time_limit_reached'
    ]),
    body('metadata').optional().isObject().custom((value) => JSON.stringify(value).length <= 4096)
  ],
  validate,
  attemptController.recordEvent
);

router.post(
  '/:testId/complete',
  authenticate,
  requireRole('student'),
  [param('testId').isInt({ min: 1 }), body('answerNote').optional().isString().trim().isLength({ max: 1000 })],
  validate,
  attemptController.completeAttempt
);

const reportFilters = [query('branchId').optional().isInt({ min: 1 }), query('testId').optional().isInt({ min: 1 }), query('studentId').optional().isInt({ min: 1 }), query('limit').optional().isInt({ min: 1, max: 500 }), query('reportFallback').optional().isIn(['true', 'false'])];
router.get('/admin/events', authenticate, requireRole('admin'), reportFilters, validate, attemptController.listEvents);
router.get('/admin/locked', authenticate, requireRole('admin'), reportFilters, validate, attemptController.listLocked);
router.get('/admin/reports', authenticate, requireRole('admin'), reportFilters, validate, attemptController.listReports);
router.post('/admin/:attemptId/allow', authenticate, requireRole('admin'), [param('attemptId').isInt({ min: 1 })], validate, attemptController.allowAttempt);

module.exports = router;
