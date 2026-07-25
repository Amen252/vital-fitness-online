const mongoose = require('mongoose');

const exerciseItemSchema = new mongoose.Schema({
  name: { type: String, required: true },
  sets: { type: Number, required: true },
  reps: { type: Number, required: true },
  durationMinutes: { type: Number },
  restSeconds: { type: Number },
  equipment: { type: String, default: '' },
  instructions: { type: String, default: '' },
  demoImageUrl: { type: String, default: '' },
  demoVideoUrl: { type: String, default: '' },
  notes: { type: String, default: '' },
}, { _id: true });

const exercisePlanSchema = new mongoose.Schema({
  coach: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  client: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  fitnessClass: { type: mongoose.Schema.Types.ObjectId, ref: 'FitnessClass' },
  title: { type: String, default: 'Workout Plan' },
  description: { type: String, default: '' },
  instructions: { type: String, default: '' },
  level: { type: String, enum: ['Beginner', 'Intermediate', 'Advanced'], default: 'Beginner' },
  dueDate: { type: Date },
  exercises: [exerciseItemSchema],
  status: {
    type: String,
    enum: ['active', 'archived'],
    default: 'active',
  },
}, { timestamps: true, optimisticConcurrency: true });

exercisePlanSchema.pre('validate', function requireTarget() {
  if (!this.client && !this.fitnessClass) {
    this.invalidate('client', 'Either client or fitnessClass is required');
  }
});

exercisePlanSchema.index({ coach: 1, client: 1, status: 1 });
exercisePlanSchema.index({ coach: 1, fitnessClass: 1, status: 1 });

module.exports = mongoose.model('ExercisePlan', exercisePlanSchema);
