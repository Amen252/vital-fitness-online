const mongoose = require('mongoose');

const SESSION_STATUSES = [
  'pending',
  'confirmed',
  'in_progress',
  'completed',
  'cancelled',
  'rescheduled',
  'no_show',
];

const SESSION_MODES = ['online', 'in_person'];

const attachmentSchema = new mongoose.Schema(
  {
    url: { type: String, required: true },
    name: { type: String, default: '' },
    uploadedAt: { type: Date, default: Date.now },
  },
  { _id: true },
);

const sessionSchema = new mongoose.Schema(
  {
    client: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    coach: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    date: { type: Date, required: true, index: true },
    durationMinutes: { type: Number, default: 60 },
    status: {
      type: String,
      enum: SESSION_STATUSES,
      default: 'pending',
      index: true,
    },
    notes: { type: String, default: '' },

    // Additive 1-on-1 fields (safe for existing Session documents)
    sessionMode: {
      type: String,
      enum: SESSION_MODES,
      default: 'in_person',
    },
    meetingLink: { type: String, default: '' },
    coachNotes: { type: String, default: '' },
    attachments: { type: [attachmentSchema], default: [] },
    followUpOf: { type: mongoose.Schema.Types.ObjectId, ref: 'Session', default: null },
    startedAt: { type: Date, default: null },
    completedAt: { type: Date, default: null },
    rescheduledFrom: { type: Date, default: null },
  },
  { timestamps: true, optimisticConcurrency: true },
);

sessionSchema.index({ coach: 1, date: 1 });
sessionSchema.index({ client: 1, date: 1 });
sessionSchema.index({ followUpOf: 1 });

module.exports = mongoose.model('Session', sessionSchema);
module.exports.SESSION_STATUSES = SESSION_STATUSES;
module.exports.SESSION_MODES = SESSION_MODES;
