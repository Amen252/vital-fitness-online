const { processAppointmentReminders } = require('../controllers/appointmentController');
const { isDatabaseConnected } = require('../config/db');

const INTERVAL_MS = 60 * 1000;

function tickAppointmentReminders() {
  if (!isDatabaseConnected()) return;
  processAppointmentReminders();
}

function startAppointmentReminderJob() {
  tickAppointmentReminders();
  setInterval(tickAppointmentReminders, INTERVAL_MS);
  console.log('Appointment reminder job started');
}

module.exports = { startAppointmentReminderJob };
