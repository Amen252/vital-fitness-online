const express = require('express');
const {
  bookSession,
  getSessions,
  updateSessionStatus,
  confirmSession,
  rescheduleSession,
  startSession,
  updateMeetingLink,
  completeSession,
  cancelSession,
  updateSessionNotes,
  updateSession,
  deleteSession,
  addSessionAttachment,
  createFollowUpSession,
} = require('../controllers/sessionController');
const auth = require('../middleware/auth');
const roles = require('../middleware/roles');
const requireApprovedCoach = require('../middleware/requireApprovedCoach');

const router = express.Router();

// Existing endpoints (kept) — coaches must be approved for write/list coach paths.
router.post('/', auth, roles('user', 'coach'), (req, res, next) => {
  if (req.user.role === 'user') return next();
  return requireApprovedCoach(req, res, next);
}, bookSession);
router.get('/', auth, (req, res, next) => {
  if (req.user.role !== 'coach') return next();
  return requireApprovedCoach(req, res, next);
}, getSessions);
router.patch('/:id/status', auth, (req, res, next) => {
  if (req.user.role === 'user') return next();
  if (req.user.role === 'coach') return requireApprovedCoach(req, res, next);
  return res.status(403).json({ message: 'Forbidden' });
}, updateSessionStatus);

// Additive 1-on-1 coach/member actions (Session collection only)
router.patch('/:id/confirm', auth, roles('coach'), requireApprovedCoach, confirmSession);
router.patch('/:id/reschedule', auth, roles('coach'), requireApprovedCoach, rescheduleSession);
router.patch('/:id/start', auth, roles('coach'), requireApprovedCoach, startSession);
router.patch('/:id/meeting-link', auth, roles('coach'), requireApprovedCoach, updateMeetingLink);
router.patch('/:id/complete', auth, roles('coach'), requireApprovedCoach, completeSession);
router.patch('/:id/cancel', auth, roles('user', 'coach'), (req, res, next) => {
  if (req.user.role === 'user') return next();
  return requireApprovedCoach(req, res, next);
}, cancelSession);
router.patch('/:id/notes', auth, roles('coach'), requireApprovedCoach, updateSessionNotes);
router.patch('/:id', auth, roles('coach'), requireApprovedCoach, updateSession);
router.delete('/:id', auth, roles('coach', 'admin'), (req, res, next) => {
  if (req.user.role === 'admin') return next();
  return requireApprovedCoach(req, res, next);
}, deleteSession);
router.post('/:id/attachments', auth, roles('coach'), requireApprovedCoach, addSessionAttachment);
router.post('/:id/follow-up', auth, roles('coach'), requireApprovedCoach, createFollowUpSession);

module.exports = router;
