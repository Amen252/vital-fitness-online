const mongoose = require('mongoose');

const exerciseItemSchema = new mongoose.Schema({
  name: { type: String, required: true },
  sets: { type: Number, required: true },
  reps: { type: Number, required: true },
  durationMinutes: { type: Number },
  restSeconds: { type: Number },
  equipment: { type: String, default: '' },
  instructions: { type: String, default: '' },
  notes: { type: String, default: '' },
  demoImageUrl: { type: String, default: '' },
  demoVideoUrl: { type: String, default: '' },
}, { _id: true });

const workoutTemplateSchema = new mongoose.Schema({
  coach: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  title: { type: String, required: true, trim: true },
  description: { type: String, default: '' },
  level: { type: String, enum: ['Beginner', 'Intermediate', 'Advanced'], default: 'Beginner' },
  notes: { type: String, default: '' },
  exercises: [exerciseItemSchema],
  status: { type: String, enum: ['active', 'archived'], default: 'active' },
}, { timestamps: true, optimisticConcurrency: true });

workoutTemplateSchema.index({ coach: 1, status: 1 });

module.exports = mongoose.model('WorkoutTemplate', workoutTemplateSchema);
