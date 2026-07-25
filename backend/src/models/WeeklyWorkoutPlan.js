const mongoose = require('mongoose');

const exerciseItemSchema = new mongoose.Schema({
  name: { type: String, required: true },
  sets: { type: Number, default: 3 },
  reps: { type: Number, default: 10 },
  durationMinutes: { type: Number },
  restSeconds: { type: Number },
  equipment: { type: String, default: '' },
  instructions: { type: String, default: '' },
  notes: { type: String, default: '' },
  demoImageUrl: { type: String, default: '' },
  demoVideoUrl: { type: String, default: '' },
}, { _id: true });

const weeklyDaySchema = new mongoose.Schema({
  dayOfWeek: { type: Number, required: true, min: 0, max: 6 },
  enabled: { type: Boolean, default: false },
  offDay: { type: Boolean, default: false },
  workoutTemplate: { type: mongoose.Schema.Types.ObjectId, ref: 'WorkoutTemplate' },
  /** Exercises assigned to this day under the selected workout title */
  exercises: [exerciseItemSchema],
  startTime: { type: String, default: '09:00' },
  endTime: { type: String, default: '10:00' },
  notes: { type: String, default: '' },
}, { _id: true });

const weeklyWorkoutPlanSchema = new mongoose.Schema({
  coach: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  client: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  fitnessClass: { type: mongoose.Schema.Types.ObjectId, ref: 'FitnessClass' },
  title: { type: String, default: 'Weekly Workout Plan' },
  /** Primary workout title for this schedule: Workout Title → Days → Exercises */
  workoutTemplate: { type: mongoose.Schema.Types.ObjectId, ref: 'WorkoutTemplate' },
  weekStartDate: { type: Date, required: true },
  days: [weeklyDaySchema],
  reminderEnabled: { type: Boolean, default: true },
  reminderMinutesBefore: { type: Number, default: 30 },
  timezoneOffsetMinutes: { type: Number, default: 0 },
  status: { type: String, enum: ['active', 'archived'], default: 'active' },
}, { timestamps: true, optimisticConcurrency: true });

weeklyWorkoutPlanSchema.pre('validate', function requireTarget() {
  if (!this.client && !this.fitnessClass) {
    this.invalidate('client', 'Either client or fitnessClass is required');
  }
});

weeklyWorkoutPlanSchema.index({ coach: 1, weekStartDate: -1 });
weeklyWorkoutPlanSchema.index({ client: 1, weekStartDate: -1 });
weeklyWorkoutPlanSchema.index({ fitnessClass: 1, weekStartDate: -1 });

module.exports = mongoose.model('WeeklyWorkoutPlan', weeklyWorkoutPlanSchema);
