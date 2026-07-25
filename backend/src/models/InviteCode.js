const mongoose = require('mongoose');
const { randomBytes } = require('crypto');

const inviteCodeSchema = new mongoose.Schema(
  {
    code: { type: String, required: true, unique: true, uppercase: true, trim: true, index: true },
    owner_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true, index: true },
    uses: { type: Number, default: 0 },
    max_uses: { type: Number, default: null },
  },
  { timestamps: true }
);

inviteCodeSchema.statics.generateCode = function generateCode() {
  // Short, readable invite code (8 chars, no ambiguous 0/O/1/I)
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = randomBytes(8);
  let code = '';
  for (let i = 0; i < 8; i += 1) {
    code += alphabet[bytes[i] % alphabet.length];
  }
  return code;
};

module.exports = mongoose.model('InviteCode', inviteCodeSchema);
