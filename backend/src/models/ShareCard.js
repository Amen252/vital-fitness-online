const mongoose = require('mongoose');
const { randomBytes } = require('crypto');

const shareCardSchema = new mongoose.Schema(
  {
    token: { type: String, required: true, unique: true, index: true },
    user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    type: {
      type: String,
      enum: ['progress', 'workout', 'weekly'],
      required: true,
    },
    payload: { type: mongoose.Schema.Types.Mixed, required: true },
    expires_at: { type: Date, required: true, index: true },
    view_count: { type: Number, default: 0 },
  },
  { timestamps: true }
);

shareCardSchema.statics.createToken = function createToken() {
  return randomBytes(16).toString('hex');
};

module.exports = mongoose.model('ShareCard', shareCardSchema);
