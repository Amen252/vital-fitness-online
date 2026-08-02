const mongoose = require('mongoose');

const mealAdherenceSchema = new mongoose.Schema({
  type: {
    type: String,
    enum: ['breakfast', 'lunch', 'dinner', 'snacks'],
    required: true,
  },
  followed: { type: Boolean, default: false },
  completedAt: { type: Date },
  notes: { type: String, default: '' },
}, { _id: false });

const dietAdherenceSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  coach: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  dietPlan: { type: mongoose.Schema.Types.ObjectId, ref: 'DietPlan' },
  date: { type: Date, required: true },
  weightKg: { type: Number },
  caloriesConsumed: { type: Number, default: 0 },
  targetCalories: { type: Number, default: 0 },
  /** True when the user marked the whole diet day complete (weekly plans). */
  dayCompleted: { type: Boolean, default: false },
  followedPlan: { type: Boolean, default: false },
  completedAt: { type: Date },
  adherencePercent: { type: Number, default: 0, min: 0, max: 100 },
  coachMarked: { type: Boolean, default: false },
  mealAdherence: [mealAdherenceSchema],
  notes: { type: String, default: '' },
}, { timestamps: true, optimisticConcurrency: true });

dietAdherenceSchema.index({ user: 1, date: 1 }, { unique: true });
dietAdherenceSchema.index({ user: 1, dayCompleted: 1, date: -1 });

module.exports = mongoose.model('DietAdherence', dietAdherenceSchema);
