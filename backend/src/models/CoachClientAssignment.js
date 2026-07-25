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

module.exports = mongoose.model('CoachClientAssignment', coachClientAssignmentSchema);
