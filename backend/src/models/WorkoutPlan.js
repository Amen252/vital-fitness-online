const mongoose = require('mongoose');

const workoutPlanSchema = new mongoose.Schema(
  {
    created_by: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    assigned_to: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    title: { type: String, default: 'Workout Plan' },
    exercises: [
      {
        name: { type: String, required: true },
        sets: { type: Number, default: 3 },
        reps: { type: Number, default: 10 },
        duration_minutes: { type: Number, default: 0 },
        rest_seconds: { type: Number, default: 60 },
        instructions: { type: String, default: '' },
      },
    ],
    start_date: { type: Date, required: true },
    end_date: { type: Date, required: true },
    active: { type: Boolean, default: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model('WorkoutPlan', workoutPlanSchema);
