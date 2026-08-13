const mongoose = require('mongoose');

const coachClientAssignmentSchema = new mongoose.Schema(
  {
    coach_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    assigned_at: { type: Date, default: Date.now },
    status: { type: String, enum: ['active', 'ended'], default: 'active' },
  },
  { timestamps: true }
);

coachClientAssignmentSchema.index({ coach_id: 1, status: 1 });
coachClientAssignmentSchema.index({ coach_id: 1, user_id: 1 }, { unique: true });
coachClientAssignmentSchema.index({ user_id: 1, status: 1 });
coachClientAssignmentSchema.index(
  { user_id: 1 },
  { unique: true, partialFilterExpression: { status: 'active' }, name: 'user_id_active_assignment_unique' },
);

module.exports = mongoose.model('CoachClientAssignment', coachClientAssignmentSchema);
