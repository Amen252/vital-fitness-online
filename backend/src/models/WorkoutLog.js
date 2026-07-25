const mongoose = require('mongoose');

const workoutLogSchema = new mongoose.Schema(
  {
    user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    plan_id: { type: mongoose.Schema.Types.ObjectId, ref: 'WorkoutPlan', default: null },
    date: { type: Date, default: Date.now },
    exercises_completed: [
      {
        name: { type: String, required: true },
        sets_completed: { type: Number, default: 0 },
        reps_completed: { type: Number, default: 0 },
        weight_kg: { type: Number, default: 0 },
      },
    ],
    calories_burned: { type: Number, default: 0 },
    duration: { type: Number, default: 0 }, // duration in minutes
  },
  { timestamps: true }
);

module.exports = mongoose.model('WorkoutLog', workoutLogSchema);
