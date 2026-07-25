const mongoose = require('mongoose');

const reviewSchema = new mongoose.Schema(
  {
    coach: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    client: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    rating: { type: Number, required: true, min: 1, max: 5 },
    comment: { type: String, default: '', trim: true, maxlength: 1000 },
  },
  { timestamps: true, optimisticConcurrency: true }
);

// One review per client per coach (updated in place if it already exists).
reviewSchema.index({ coach: 1, client: 1 }, { unique: true });

module.exports = mongoose.model('Review', reviewSchema);
