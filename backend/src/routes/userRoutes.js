const express = require('express');
const { body, validationResult } = require('express-validator');
const {
  getProfile,
  updateProfile,
  updateProfilePhoto,
  getCoachingAssignment,
  getTrainers,
  getTrainerById,
  getPublicSchedule,
  getMyClasses,
  getAvailableClasses,
  getClassById,
  joinClass,
  submitCoachApplication,
  getMyCoachApplication,
} = require('../controllers/userController');
const {
  submitCoachRequest,
  cancelCoachRequest,
  getMyCoachRequest,
} = require('../controllers/coachRequestController');
const { getUserNotifications, markNotificationRead } = require('../controllers/notificationController');
const { submitReview, getCoachReviews, deleteMyReview } = require('../controllers/reviewController');
const {
  getUserExercisePlans,
  completeWorkout,
  getUserWorkoutProgress,
} = require('../controllers/workoutPlanController');
const { getUserWorkoutSchedules, completeWorkoutSchedule } = require('../controllers/workoutScheduleController');
const {
  requestAppointment,
  getUserAppointments,
  getCoachAvailability,
  bookAppointment,
  cancelAppointmentByUser,
} = require('../controllers/appointmentController');
const { getUserWeeklySchedule } = require('../controllers/weeklyWorkoutPlanController');
const auth = require('../middleware/auth');
const roles = require('../middleware/roles');

const router = express.Router();

const validateProfileUpdate = [
  body('age').optional().isInt({ min: 0, max: 120 }),
  body('heightCm').optional().isFloat({ min: 20, max: 300 }),
  body('weightKg').optional().isFloat({ min: 2, max: 500 }),
  body('goals').optional().isArray(),
  body('goals.*').optional().isString().trim(),
  body('experience').optional().isString().trim(),
  body('specialization').optional().isArray(),
  body('specialization.*').optional().isString().trim(),
  (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    return next();
  },
];

router.get('/profile', auth, roles('user', 'coach'), getProfile);
router.put('/profile', auth, roles('user', 'coach'), validateProfileUpdate, updateProfile);
router.put('/profile/photo', auth, roles('user', 'coach'), updateProfilePhoto);
router.get('/coaching', auth, roles('user', 'coach'), getCoachingAssignment);
router.get('/schedule/all', auth, roles('user', 'coach', 'admin'), getPublicSchedule);
router.get('/classes', auth, roles('user'), getMyClasses);
router.get('/classes/available', auth, roles('user'), getAvailableClasses);
router.get('/classes/:id', auth, roles('user'), getClassById);
router.post('/classes/:id/join', auth, roles('user'), joinClass);
router.get('/trainers', auth, roles('user', 'admin'), getTrainers);
router.get('/trainers/:id', auth, roles('user', 'admin'), getTrainerById);
router.get('/trainers/:coachId/reviews', auth, roles('user', 'admin'), getCoachReviews);
router.post('/trainers/:coachId/reviews', auth, roles('user'), submitReview);
router.delete('/trainers/:coachId/reviews', auth, roles('user'), deleteMyReview);
router.get('/workout-schedules/weekly', auth, roles('user'), getUserWeeklySchedule);
router.get('/workout-schedules', auth, roles('user'), getUserWorkoutSchedules);
router.patch('/workout-schedules/:scheduleId/complete', auth, roles('user'), completeWorkoutSchedule);
router.get('/workouts', auth, roles('user'), getUserExercisePlans);
router.get('/workouts/progress', auth, roles('user'), getUserWorkoutProgress);
router.patch('/workouts/:planId/complete', auth, roles('user'), completeWorkout);
router.get('/notifications', auth, roles('user', 'coach'), getUserNotifications);
router.patch('/notifications/:id/read', auth, roles('user', 'coach'), markNotificationRead);
router.post('/coach-application', auth, roles('user'), submitCoachApplication);
router.get('/coach-application', auth, roles('user', 'coach'), getMyCoachApplication);
router.get('/appointments', auth, roles('user'), getUserAppointments);
router.get('/appointments/availability', auth, roles('user'), getCoachAvailability);
router.post('/appointments/request', auth, roles('user'), requestAppointment);
router.post('/appointments/book', auth, roles('user'), bookAppointment);
router.patch('/appointments/:id/cancel', auth, roles('user'), cancelAppointmentByUser);

router.post('/coach-request', auth, roles('user'), submitCoachRequest);
router.delete('/coach-request', auth, roles('user'), cancelCoachRequest);
router.get('/coach-request', auth, roles('user'), getMyCoachRequest);

module.exports = router;
