const mongoose = require('mongoose');

const scheduleCompletionSchema = new mongoose.Schema({
  workoutSchedule: { type: mongoose.Schema.Types.ObjectId, ref: 'WorkoutSchedule', required: true },
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  coach: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  status: {
    type: String,
    enum: ['pending', 'completed', 'missed'],
    default: 'pending',
  },
  completedAt: { type: Date },
}, { timestamps: true, optimisticConcurrency: true });

scheduleCompletionSchema.index({ workoutSchedule: 1, user: 1 }, { unique: true });
scheduleCompletionSchema.index({ user: 1, status: 1 });
scheduleCompletionSchema.index({ coach: 1, createdAt: -1 });

module.exports = mongoose.model('ScheduleCompletion', scheduleCompletionSchema);
