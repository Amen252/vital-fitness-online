const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema(
  {
    assignment: { type: mongoose.Schema.Types.ObjectId, ref: 'CoachAssignment', required: true },
    sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    receiver: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    body: { type: String, required: true, trim: true },
    read: { type: Boolean, default: false },
    editedAt: { type: Date },
  },
  { timestamps: true, optimisticConcurrency: true }
);

messageSchema.index({ assignment: 1, createdAt: -1 });
messageSchema.index({ receiver: 1, read: 1 });

module.exports = mongoose.model('Message', messageSchema);
