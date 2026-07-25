const mongoose = require('mongoose');

const coachAssignmentSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    coach: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    status: { type: String, default: 'active' },
    customDietPlan: {
      breakfast: String,
      lunch: String,
      dinner: String,
      snacks: String,
    },
    customWorkoutPlan: String,
    assignedArticles: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Article' }],
    feedback: [
      {
        note: String,
        createdAt: { type: Date, default: Date.now },
      },
    ],
  },

  { timestamps: true, optimisticConcurrency: true }
);

module.exports = mongoose.model('CoachAssignment', coachAssignmentSchema);
