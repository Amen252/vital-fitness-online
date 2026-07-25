const mongoose = require('mongoose');

const waterLogSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    date: { type: Date, default: Date.now },
    amountMl: { type: Number, required: true },
  },
  { timestamps: true, optimisticConcurrency: true }
);

module.exports = mongoose.model('WaterLog', waterLogSchema);
