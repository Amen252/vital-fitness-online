const mongoose = require('mongoose');

const fitnessClassSchema = new mongoose.Schema(
  {
    coach: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    title: { type: String, required: true },
    description: { type: String, default: '' },
    category: { type: String, default: 'General' },
    date: { type: Date, required: true },
    durationMinutes: { type: Number, default: 60 },
    capacity: { type: Number, default: 20 },
    enrolledStudents: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    attendance: [
      {
        student: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        present: { type: Boolean, default: true },
        markedAt: { type: Date, default: Date.now },
      },
    ],
    status: {
      type: String,
      enum: ['scheduled', 'active', 'completed', 'cancelled'],
      default: 'scheduled',
    },
  },
  { timestamps: true, optimisticConcurrency: true }
);

module.exports = mongoose.model('FitnessClass', fitnessClassSchema);
