const router = require('express').Router();
const { body } = require('express-validator');
const appErrorController = require('../controllers/app-error.controller');
const { authenticate } = require('../middleware/auth.middleware');
const { validate } = require('../middleware/validate.middleware');

router.post(
  '/',
  authenticate,
  [
    body('severity').optional().isIn(['error', 'crash']),
    body('source').optional().trim().isLength({ max: 40 }),
    body('page').optional({ nullable: true, checkFalsy: true }).trim().isLength({ max: 120 }),
    body('message').trim().isLength({ min: 1, max: 4000 }),
    body('stackTrace').optional({ nullable: true, checkFalsy: true }).trim().isLength({ max: 12000 }),
    body('devicePlatform').optional({ nullable: true, checkFalsy: true }).trim().isLength({ max: 80 }),
    body('deviceModel').optional({ nullable: true, checkFalsy: true }).trim().isLength({ max: 160 }),
    body('appVersion').optional({ nullable: true, checkFalsy: true }).trim().isLength({ max: 40 }),
    body('appBuild').optional({ nullable: true, checkFalsy: true }).trim().isLength({ max: 40 }),
    body('metadata').optional().isObject()
  ],
  validate,
  appErrorController.record
);

module.exports = router;
