const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    // Controllers and mobile app use `user` + `read`
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    // Kept for older records that used recipient_id
    recipient_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null, index: true },
    type: {
      type: String,
      required: true,
      default: 'update',
    },
    message: { type: String, required: true },
    data: { type: mongoose.Schema.Types.Mixed, default: null },
    read: { type: Boolean, default: false },
    read_at: { type: Date, default: null },
  },
  { timestamps: true }
);

notificationSchema.pre('validate', function syncRecipient() {
  if (this.user && !this.recipient_id) {
    this.recipient_id = this.user;
  }
  if (this.recipient_id && !this.user) {
    this.user = this.recipient_id;
  }
});

module.exports = mongoose.model('Notification', notificationSchema);
