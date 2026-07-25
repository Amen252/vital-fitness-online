const mongoose = require('mongoose');

const scheduleSchema = new mongoose.Schema(
  {
    coach: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    client: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    weekStart: { type: Date, required: true },
    sessions: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Session' }],
  },
  { timestamps: true, optimisticConcurrency: true }
);

module.exports = mongoose.model('Schedule', scheduleSchema);
