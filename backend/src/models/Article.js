const mongoose = require('mongoose');

const articleSchema = new mongoose.Schema(
  {
    title: { type: String, required: true },
    category: { type: String, default: 'Wellness' },
    summary: { type: String, required: true },
    body: { type: String, required: true },
    isPublished: { type: Boolean, default: true },
    groups: [
      {
        name: { type: String, required: true },
        students: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
      },
    ],
  },
  { timestamps: true, optimisticConcurrency: true }
);

module.exports = mongoose.model('Article', articleSchema);
