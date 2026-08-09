const mongoose = require('mongoose');

const mealSchema = new mongoose.Schema({
  type: {
    type: String,
    enum: ['breakfast', 'lunch', 'dinner', 'snacks'],
    required: true,
  },
  name: { type: String, default: '' },
  /** Free-text food list / ingredients summary */
  description: { type: String, default: '' },
  /** Structured food items (optional; description still supported) */
  foodItems: { type: [String], default: [] },
  portionSize: { type: String, default: '' },
  calories: { type: Number, default: 0, min: 0 },
  protein: { type: Number, default: 0, min: 0 },
  carbs: { type: Number, default: 0, min: 0 },
  fats: { type: Number, default: 0, min: 0 },
  /** Local wall-clock reminder, e.g. "08:00" */
  reminderTime: { type: String, default: '' },
  prepInstructions: { type: String, default: '' },
  mealNotes: { type: String, default: '' },
}, { _id: true });

const dietDaySchema = new mongoose.Schema({
  dayOfWeek: { type: Number, required: true, min: 0, max: 6 }, // 0 = Monday
  /** Calendar date for this weekday within the plan week (derived from weekStartDate). */
  date: { type: Date, default: null },
  meals: [mealSchema],
  notes: { type: String, default: '' },
}, { _id: true });

const dietPlanSchema = new mongoose.Schema({
  coach: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  client: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  fitnessClass: { type: mongoose.Schema.Types.ObjectId, ref: 'FitnessClass' },
  title: { type: String, default: 'Diet Plan' },
  goal: {
    type: String,
    enum: ['weight_loss', 'muscle_gain', 'maintenance'],
    default: 'maintenance',
  },
  /** single_day = flat meals (+ optional targetDayOfWeek); weekly = days[0..6] */
  planType: {
    type: String,
    enum: ['single_day', 'weekly'],
    default: 'single_day',
  },
  /** For single_day plans: which weekday (0=Mon…6=Sun) this plan targets */
  targetDayOfWeek: { type: Number, min: 0, max: 6, default: null },
  /**
   * Weekly plans only: Monday of the plan week (date-only UTC noon storage).
   * Each days[].date is derived from this — one Weekly Diet Plan, not 7 separate plans.
   */
  weekStartDate: { type: Date, default: null },
  meals: [mealSchema],
  days: [dietDaySchema],
  dailyCalories: { type: Number, required: true, min: 1 },
  notes: { type: String, default: '' },
  status: {
    type: String,
    enum: ['draft', 'active', 'completed', 'archived'],
    default: 'active',
  },
  /** When this plan became active / was assigned */
  assignedAt: { type: Date },
}, { timestamps: true, optimisticConcurrency: true });

dietPlanSchema.pre('validate', function requireTarget() {
  if (!this.client && !this.fitnessClass) {
    this.invalidate('client', 'Either client or fitnessClass is required');
  }
  if (this.client && this.fitnessClass) {
    this.invalidate('client', 'Plan cannot target both a client and a group');
  }
});

dietPlanSchema.index({ coach: 1, client: 1, status: 1 });
dietPlanSchema.index({ coach: 1, fitnessClass: 1, status: 1 });
dietPlanSchema.index({ status: 1, updatedAt: -1 });

module.exports = mongoose.model('DietPlan', dietPlanSchema);
