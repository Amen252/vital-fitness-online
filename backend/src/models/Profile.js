const mongoose = require('mongoose');
const calcBmi = require('../utils/calcBmi');

const profileSchema = new mongoose.Schema(
  {
    age: Number,
    heightCm: Number,
    weightKg: Number,
    bmi: Number,
    photoUrl: { type: String, default: '' },
    goals: [String],
    experience: String,
    specialization: [String],
    bio: String,
    phone: String,
    location: String,
    yearsExperience: Number,
    certifications: String,
    workingDays: {
      type: [String],
      default: [],
    },
    appointmentDays: {
      type: [String],
      default: [],
    },
    workingHoursStart: { type: String, default: '09:00' },
    workingHoursEnd: { type: String, default: '17:00' },
    appointmentDurationMinutes: { type: Number, default: 60 },
    dayAvailability: [
      {
        day: { type: String, required: true },
        start: { type: String, required: true },
        end: { type: String, required: true },
      },
    ],
  },
  { timestamps: true, optimisticConcurrency: true }
);

profileSchema.pre('save', async function saveBmi() {
  this.bmi = calcBmi(this.heightCm, this.weightKg);
});


module.exports = mongoose.model('Profile', profileSchema);
