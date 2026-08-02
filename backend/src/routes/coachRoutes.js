const express = require('express');
const {
  createFeedback,
  getClientDetail,
  getClients,
  updateClientPlan,
  assignArticle,
  removeArticle,
  deleteAssignment,
  updateAssignment,
  createNotification,
  getNotifications,
  createSchedule,
  getSchedules,
  getExerciseLibrary,
  getPendingActivities,
  updateActivityStatus,
  getPendingWorkoutSubmissions,
  reviewWorkoutSubmission,
  getCoachReports,
  getClasses,
  getClassDetail,
  createClass,
  updateClass,
  deleteClass,
  enrollStudent,
  unenrollStudent,
  changeClientGroup,
  markAttendance,
} = require('../controllers/coachController');
const {
  getCoachRequests,
  approveCoachRequest,
  rejectCoachRequest,
} = require('../controllers/coachRequestController');
const {
  createWorkoutTemplate,
  getWorkoutTemplates,
  getWorkoutTemplateById,
  updateWorkoutTemplate,
  deleteWorkoutTemplate,
  getWorkoutPresets,
} = require('../controllers/workoutTemplateController');
const {
  createWeeklyWorkoutPlan,
  getCoachWeeklyWorkoutPlans,
  updateWeeklyWorkoutPlan,
  deleteWeeklyWorkoutPlan,
} = require('../controllers/weeklyWorkoutPlanController');
const {
  createWorkoutSchedule,
  getCoachWorkoutSchedules,
  getWorkoutScheduleById,
  updateWorkoutSchedule,
  deleteWorkoutSchedule,
} = require('../controllers/workoutScheduleController');
const {
  createExercisePlan,
  getExercisePlans,
  getGroupExercisePlans,
  getExercisePlanById,
  updateExercisePlan,
  deleteExercisePlan,
  getClientWorkoutProgress,
  getGroupWorkoutProgress,
  sendWorkoutReminder,
} = require('../controllers/workoutPlanController');
const {
  createCoachAppointment,
  getCoachAppointments,
  approveAppointment,
  rejectAppointment,
  rescheduleAppointment,
  completeAppointment,
  updateAppointmentNotes,
  cancelAppointmentByCoach,
} = require('../controllers/appointmentController');
const {
  createOrUpdateDietPlan,
  getCoachDietPlans,
  getDietPlanCompletions,
  getDietPlanById,
  getClientDietPlan,
  getGroupDietPlan,
  getGroupDietProgress,
  updateDietPlanById,
  archiveDietPlan,
  sendDietPlanAgain,
  getClientDietProgress,
  markClientAdherence,
  sendMealReminders,
  sendGroupMealReminders,
} = require('../controllers/dietPlanController');
const auth = require('../middleware/auth');
const roles = require('../middleware/roles');
const requireApprovedCoach = require('../middleware/requireApprovedCoach');

const router = express.Router();

router.use(auth, roles('coach'), requireApprovedCoach);

router.get('/appointments', getCoachAppointments);
router.post('/appointments', createCoachAppointment);
router.patch('/appointments/:id/approve', approveAppointment);
router.patch('/appointments/:id/reject', rejectAppointment);
router.patch('/appointments/:id/reschedule', rescheduleAppointment);
router.patch('/appointments/:id/complete', completeAppointment);
router.patch('/appointments/:id/cancel', cancelAppointmentByCoach);
router.patch('/appointments/:id/notes', updateAppointmentNotes);

router.get('/requests', getCoachRequests);
router.patch('/requests/:id/approve', approveCoachRequest);
router.patch('/requests/:id/reject', rejectCoachRequest);
router.get('/clients', getClients);
router.get('/clients/:id', getClientDetail);
router.patch('/clients/:id', updateAssignment);
router.patch('/clients/:id/group', changeClientGroup);
router.delete('/clients/:id', deleteAssignment);
router.post('/feedback', createFeedback);
router.put('/clients/plan', updateClientPlan);
router.post('/clients/assign-article', assignArticle);
router.post('/clients/remove-article', removeArticle);

router.get('/workout-templates', getWorkoutTemplates);
router.get('/workout-presets', getWorkoutPresets);
router.post('/workout-templates', createWorkoutTemplate);
router.get('/workout-templates/:id', getWorkoutTemplateById);
router.put('/workout-templates/:id', updateWorkoutTemplate);
router.delete('/workout-templates/:id', deleteWorkoutTemplate);

router.get('/weekly-workout-plans', getCoachWeeklyWorkoutPlans);
router.post('/weekly-workout-plans', createWeeklyWorkoutPlan);
router.put('/weekly-workout-plans/:id', updateWeeklyWorkoutPlan);
router.delete('/weekly-workout-plans/:id', deleteWeeklyWorkoutPlan);

router.post('/workout-schedules', createWorkoutSchedule);
router.get('/workout-schedules', getCoachWorkoutSchedules);
router.get('/workout-schedules/:id', getWorkoutScheduleById);
router.put('/workout-schedules/:id', updateWorkoutSchedule);
router.delete('/workout-schedules/:id', deleteWorkoutSchedule);

router.post('/exercise-plans', createExercisePlan);
router.get('/exercise-plans/groups/:classId/progress', getGroupWorkoutProgress);
router.get('/exercise-plans/groups/:classId', getGroupExercisePlans);
router.get('/exercise-plans/client/:clientId/progress', getClientWorkoutProgress);
router.get('/exercise-plans/client/:clientId', getExercisePlans);
router.get('/exercise-plans/:clientId', getExercisePlans);
router.get('/exercise-plans/detail/:planId', getExercisePlanById);
router.put('/exercise-plans/:planId', updateExercisePlan);
router.delete('/exercise-plans/:planId', deleteExercisePlan);
router.post('/exercise-plans/:planId/reminder', sendWorkoutReminder);

router.get('/diet-plans/completions', getDietPlanCompletions);
router.get('/diet-plans/groups/:classId/progress', getGroupDietProgress);
router.get('/diet-plans/groups/:classId', getGroupDietPlan);
router.get('/diet-plans', getCoachDietPlans);
router.get('/diet-plans/client/:clientId', getClientDietPlan);
router.get('/diet-plans/client/:clientId/progress', getClientDietProgress);
router.post('/diet-plans/client/:clientId/adherence', markClientAdherence);
router.post('/diet-plans/client/:clientId/reminders', sendMealReminders);
router.get('/diet-plans/:id', getDietPlanById);
router.post('/diet-plans/:id/send', sendDietPlanAgain);
router.post('/diet-plans', createOrUpdateDietPlan);
router.put('/diet-plans/:id', updateDietPlanById);
router.delete('/diet-plans/:id', archiveDietPlan);
router.post('/diet-plans/groups/:classId/reminders', sendGroupMealReminders);

router.post('/notifications', createNotification);
router.get('/notifications', getNotifications);

router.post('/schedules', createSchedule);
router.get('/schedules', getSchedules);

router.get('/exercises', getExerciseLibrary);
router.get('/activities/pending', getPendingActivities);
router.patch('/activities/:id/status', updateActivityStatus);
router.get('/workout-submissions/pending', getPendingWorkoutSubmissions);
router.patch('/workout-submissions/:id/review', reviewWorkoutSubmission);
router.get('/reports', getCoachReports);

router.get('/classes', getClasses);
router.get('/classes/:id', getClassDetail);
router.post('/classes', createClass);
router.put('/classes/:id', updateClass);
router.delete('/classes/:id', deleteClass);
router.post('/classes/:id/enroll', enrollStudent);
router.delete('/classes/:id/enroll/:userId', unenrollStudent);
router.patch('/classes/:id/attendance', markAttendance);

module.exports = router;
