const mongoose = require('mongoose');

const coachRequestSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    coach: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    message: { type: String, default: '', trim: true },
    status: {
      type: String,
      enum: ['pending', 'approved', 'rejected', 'cancelled'],
      default: 'pending',
    },
    fitnessClass: { type: mongoose.Schema.Types.ObjectId, ref: 'FitnessClass' },
    reviewedAt: { type: Date },
  },
  { timestamps: true, optimisticConcurrency: true },
);

coachRequestSchema.index({ user: 1, coach: 1 });
coachRequestSchema.index({ coach: 1, status: 1 });
coachRequestSchema.index(
  { user: 1 },
  { unique: true, partialFilterExpression: { status: 'pending' } },
);

module.exports = mongoose.model('CoachRequest', coachRequestSchema);
