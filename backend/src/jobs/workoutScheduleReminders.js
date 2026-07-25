const { processWorkoutScheduleReminders } = require('../controllers/workoutScheduleController');
const { isDatabaseConnected } = require('../config/db');

const INTERVAL_MS = 60 * 1000;

function tickWorkoutScheduleReminders() {
  if (!isDatabaseConnected()) return;
  processWorkoutScheduleReminders();
}

function startWorkoutScheduleReminderJob() {
  tickWorkoutScheduleReminders();
  setInterval(tickWorkoutScheduleReminders, INTERVAL_MS);
  console.log('Workout schedule reminder job started');
}

module.exports = { startWorkoutScheduleReminderJob };
