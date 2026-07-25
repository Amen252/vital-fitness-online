const express = require('express');
const { body } = require('express-validator');
const router = express.Router();
const auth = require('../middleware/auth');
const roles = require('../middleware/roles');
const {
  getDashboardStats,
  getUsers, getUserDetail, getCoachDetail, getAdminMe, createUser, deleteUser, updateUserRole, updateUser, updateUserStatus,
  getTrainers, deleteCoach,
  getWorkoutStats,
  getExerciseTypes, approveExercise, rejectExercise, rejectExerciseType, deleteExerciseType,
  getMealStats,
  getSchedule, createAssignment, updateAssignmentStatus, deleteAssignment,
  getClasses, createClass, updateClass, deleteClass,
  getStatistics,
  sendAnnouncement,
  getCoachApplications,
  approveCoachApplication,
  rejectCoachApplication,
  getAppointments,
  getCoachingProgress,
  getAdminDietPlans,
  getAdminDietAdherence,
  getAdminWorkouts,
  getReports,
  regeneratePassword,
  getAuditLogs,
} = require('../controllers/adminController');

// All admin routes require auth + admin role
router.use(auth, roles('admin'));

router.get('/me', getAdminMe);
router.get('/dashboard', getDashboardStats);
router.get('/statistics', getStatistics);
router.get('/reports', getReports);
router.get('/audit-logs', getAuditLogs);
router.get('/users', getUsers);
router.get('/users/:id/detail', getUserDetail);
router.post('/users/:id/regenerate-password', regeneratePassword);
router.post('/users', createUser);
router.delete('/users/:id', deleteUser);
router.patch('/users/:id/role', updateUserRole);
router.patch('/users/:id', updateUser);
router.patch('/users/:id/status', updateUserStatus);
router.post('/notifications', sendAnnouncement);
router.get('/coach-applications', getCoachApplications);
router.patch('/coach-applications/:id/approve', approveCoachApplication);
router.patch('/coach-applications/:id/reject', rejectCoachApplication);
router.get('/trainers', getTrainers);
router.get('/trainers/:id/detail', getCoachDetail);
router.delete('/trainers/:id', deleteCoach);
router.get('/appointments', getAppointments);
router.get('/coaching-progress', getCoachingProgress);
router.get('/diet-plans', getAdminDietPlans);
router.get('/diet-adherence', getAdminDietAdherence);
router.get('/workouts', getWorkoutStats);
router.get('/workouts/overview', getAdminWorkouts);
router.get('/exercises', getExerciseTypes);
router.patch('/exercises/:id/approve', approveExercise);
router.patch('/exercises/:id/reject', rejectExercise);
router.patch('/exercises/type/:type/reject', rejectExerciseType);
router.delete('/exercises/type/:type', deleteExerciseType);
router.get('/meals', getMealStats);
router.get('/schedule', getSchedule);
router.post('/schedule', createAssignment);
router.patch('/schedule/:id/status', updateAssignmentStatus);
router.patch('/schedule/:id', updateAssignmentStatus);
router.delete('/schedule/:id', deleteAssignment);
router.get('/classes', getClasses);
router.post('/classes', createClass);
router.put('/classes/:id', updateClass);
router.delete('/classes/:id', deleteClass);

module.exports = router;
