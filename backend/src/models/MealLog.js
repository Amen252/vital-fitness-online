const mongoose = require('mongoose');

const mealLogSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    date: { type: Date, default: Date.now },
    mealName: { type: String, required: true },
    calories: { type: Number, required: true },
    protein: { type: Number, default: 0 },
    carbs: { type: Number, default: 0 },
    fats: { type: Number, default: 0 },
  },
  { timestamps: true, optimisticConcurrency: true }
);

mealLogSchema.index({ user: 1, date: -1 });

module.exports = mongoose.model('MealLog', mealLogSchema);
