const mongoose = require('mongoose');

const auditLogSchema = new mongoose.Schema(
  {
    actor_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    action: { type: String, required: true }, // e.g., 'CREATE_USER', 'SUSPEND_USER', 'PASSWORD_RESET'
    target_type: { type: String, required: true }, // e.g., 'User', 'CoachApplication'
    target_id: { type: mongoose.Schema.Types.ObjectId, required: true },
    details: { type: mongoose.Schema.Types.Mixed }, // any additional details
    created_at: { type: Date, default: Date.now },
  },
  { timestamps: { createdAt: 'created_at', updatedAt: false } }
);

module.exports = mongoose.model('AuditLog', auditLogSchema);
