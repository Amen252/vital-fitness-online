const mongoose = require('mongoose');

const coachApplicationSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
    phone: { type: String, required: true, trim: true },
    age: { type: Number, required: true },
    location: { type: String, required: true, trim: true },
    yearsExperience: { type: Number, required: true },
    certifications: { type: String, required: true, trim: true },
    specialization: { type: String, required: true, trim: true },
    bio: { type: String, required: true, trim: true },
    experience: { type: String, required: true, trim: true },
    message: { type: String, required: true, trim: true },
    workingDays: {
      type: [String],
      default: [],
    },
    appointmentDays: {
      type: [String],
      default: [],
    },
    dayAvailability: {
      type: [mongoose.Schema.Types.Mixed],
      default: [],
    },
    appointmentDurationMinutes: {
      type: Number,
      default: 60,
    },
    status: {
      type: String,
      enum: ['pending', 'approved', 'rejected'],
      default: 'pending',
    },
    reviewedAt: { type: Date },
  },
  { timestamps: true, optimisticConcurrency: true },
);

module.exports = mongoose.model('CoachApplication', coachApplicationSchema);
