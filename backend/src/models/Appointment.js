const mongoose = require('mongoose');

const APPOINTMENT_STATUSES = [
  'pending',
  'approved',
  'confirmed',
  'completed',
  'rejected',
  'cancelled',
  'rescheduled',
  'no_show',
];

const appointmentSchema = new mongoose.Schema(
  {
    // Canonical fields used by appointmentController
    client: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null, index: true },
    coach: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null, index: true },
    dateTime: { type: Date, default: null, index: true },
    durationMinutes: { type: Number, default: 60 },
    type: {
      type: String,
      enum: ['user_request', 'coach_created', 'admin_created', 'booked', 'other'],
      default: 'user_request',
    },
    notes: { type: String, default: '' },
    coachNotes: { type: String, default: '' },
    rejectionReason: { type: String, default: '' },
    fitnessClass: { type: mongoose.Schema.Types.ObjectId, ref: 'FitnessClass', default: null },
    status: {
      type: String,
      enum: APPOINTMENT_STATUSES,
      default: 'pending',
      index: true,
    },

    // Mirrored fields for dashboardController / older readers
    user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    coach_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    datetime: { type: Date, default: null },
    date: { type: Date, default: null },
    time: { type: String, default: '' },
    duration: { type: Number, default: 60 },
  },
  { timestamps: true }
);

appointmentSchema.pre('validate', function syncMirroredFields() {
  if (this.client && !this.user_id) this.user_id = this.client;
  if (this.user_id && !this.client) this.client = this.user_id;
  if (this.coach && !this.coach_id) this.coach_id = this.coach;
  if (this.coach_id && !this.coach) this.coach = this.coach_id;

  if (this.dateTime && !this.datetime) this.datetime = this.dateTime;
  if (this.datetime && !this.dateTime) this.dateTime = this.datetime;

  if (this.dateTime) {
    this.date = this.dateTime;
    try {
      this.time = new Date(this.dateTime).toISOString().slice(11, 16);
    } catch {
      /* ignore */
    }
  }

  if (this.durationMinutes != null) this.duration = this.durationMinutes;
  else if (this.duration != null) this.durationMinutes = this.duration;

  // Normalize confirmed ↔ approved for mixed readers
  if (this.status === 'confirmed') this.status = 'approved';
});

appointmentSchema.index({ coach: 1, dateTime: 1 });
appointmentSchema.index({ client: 1, dateTime: 1 });
appointmentSchema.index({ coach_id: 1, datetime: 1 });
appointmentSchema.index({ user_id: 1, datetime: 1 });

module.exports = mongoose.model('Appointment', appointmentSchema);
module.exports.APPOINTMENT_STATUSES = APPOINTMENT_STATUSES;
