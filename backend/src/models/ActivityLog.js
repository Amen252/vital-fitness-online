const mongoose = require('mongoose');

const activityLogSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    date: { type: Date, default: Date.now },
    activityType: { type: String, required: true },
    durationMinutes: { type: Number, required: true },
    caloriesBurned: { type: Number, default: 0 },
    sets: [
      {
        reps: { type: Number },
        weight: { type: Number },
      }
    ],
    status: {
      type: String,
      enum: ['pending', 'approved', 'rejected'],
      default: 'pending',
    },
  },
  { timestamps: true, optimisticConcurrency: true }
);

activityLogSchema.index({ user: 1, date: -1 });
activityLogSchema.index({ user: 1, status: 1 });

module.exports = mongoose.model('ActivityLog', activityLogSchema);
