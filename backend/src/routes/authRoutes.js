const express = require('express');
const { body } = require('express-validator');
const {
  login,
  adminLogin,
  me,
  register,
  registerCoach,
  logout,
  changePassword,
  forgotPassword,
  resetPassword,
} = require('../controllers/authController');
const auth = require('../middleware/auth');
const { MAX_PASSWORD_LENGTH } = require('../utils/passwordUtils');

const router = express.Router();

router.post('/login', [
  body('password').notEmpty().isLength({ max: MAX_PASSWORD_LENGTH }),
  body().custom((_, { req }) => {
    const identity = String(req.body.username || req.body.email || '').trim();
    if (!identity) {
      throw new Error('Username or email is required');
    }
    return true;
  }),
], login);

router.post('/admin/login', [
  body('password').notEmpty().isLength({ max: MAX_PASSWORD_LENGTH }),
  body().custom((_, { req }) => {
    const identity = String(req.body.username || req.body.email || '').trim();
    if (!identity) {
      throw new Error('Username or email is required');
    }
    return true;
  }),
], adminLogin);

router.post('/logout', logout);

router.get('/me', auth, me);

router.post(
  '/change-password',
  auth,
  [
    body('currentPassword').notEmpty().withMessage('Current password is required'),
    body('newPassword')
      .isLength({ min: 6, max: MAX_PASSWORD_LENGTH })
      .withMessage('New password must be between 6 and 128 characters'),
  ],
  changePassword,
);

// Fallbacks/disabled endpoints kept for route-mapping safety
router.post('/register', [
  body('username').notEmpty().withMessage('Username is required'),
  body('full_name').notEmpty().withMessage('Full name is required'),
  body('password').isLength({ min: 6, max: MAX_PASSWORD_LENGTH }),
], register);
router.post('/register-coach', registerCoach);
router.post('/forgot-password', forgotPassword);
router.post('/reset-password', resetPassword);

module.exports = router;
