const mongoose = require('mongoose');

const dailyTrackingSchema = new mongoose.Schema(
  {
    user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    date: { type: Date, required: true }, // normal Date object, but typically normalized to midnight
    water_ml: { type: Number, default: 0 },
    calories_consumed: { type: Number, default: 0 },
    calories_burned: { type: Number, default: 0 },
    steps: { type: Number, default: 0 },
  },
  { timestamps: true }
);

// Unique index to prevent duplicate tracking logs for the same user on the same day
dailyTrackingSchema.index({ user_id: 1, date: 1 }, { unique: true });

module.exports = mongoose.model('DailyTracking', dailyTrackingSchema);
