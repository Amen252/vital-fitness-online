const mongoose = require('mongoose');

const coachApplicationSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
    phone: { type: String, required: true, trim: true },
    age: { type: Number, required: true },
    location: { type: String, required: true, trim: true },
    yearsExperience: { type: Number, required: true },
    certifications: { type: String, required: true, trim: true },
    /** Uploaded certificate files (ImageKit CDN URLs) for admin review */
    certificateFiles: {
      type: [
        {
          url: { type: String, required: true },
          fileName: { type: String, default: '' },
          mimeType: { type: String, default: '' },
          uploadedAt: { type: Date, default: Date.now },
        },
      ],
      default: [],
    },
    specialization: { type: String, required: true, trim: true },
    bio: { type: String, default: '', trim: true },
    experience: { type: String, default: '', trim: true },
    message: { type: String, default: '', trim: true },
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
    rejectionReason: { type: String, default: '', trim: true },
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
