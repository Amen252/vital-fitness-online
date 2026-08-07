const mongoose = require('mongoose');
const { comparePassword, hashPasswordIfNeeded } = require('../utils/passwordUtils');

const adminDataSchema = new mongoose.Schema(
  {
    permissions: { type: String, enum: ['super-admin', 'support-admin'], default: 'super-admin' },
  },
  { _id: false }
);

const coachDataSchema = new mongoose.Schema(
  {
    approval_status: { type: String, enum: ['pending', 'approved', 'rejected'], default: 'pending' },
    specialties: { type: [String], default: [] },
    certifications: { type: [String], default: [] },
    /** Uploaded certificate images/PDFs (CDN URLs) for admin review */
    certificateFiles: {
      type: [
        {
          url: { type: String, required: true },
          fileName: { type: String, default: '' },
          mimeType: { type: String, default: '' },
          uploadedAt: { type: Date, default: Date.now },
        },
      ],
      default: [],
    },
    bio: { type: String, default: '' },
    experience: { type: String, default: '' },
    location: { type: String, default: '' },
    age: { type: Number, default: null },
    years_experience: { type: Number, default: 0 },
    appointmentDurationMinutes: { type: Number, default: 60 },
    dayAvailability: { type: [mongoose.Schema.Types.Mixed], default: [] },
    availability: {
      workingDays: { type: [String], default: [] },
      appointmentDays: { type: [String], default: [] },
      workingHoursStart: { type: String, default: '09:00' },
      workingHoursEnd: { type: String, default: '17:00' },
    },
    max_clients: { type: Number, default: null },
  },
  { _id: false }
);

const clientDataSchema = new mongoose.Schema(
  {
    assigned_coach_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    age: { type: Number, default: null },
    gender: { type: String, default: '' },
    height: { type: Number, default: null },
    weight: { type: Number, default: null },
    weight_history: [
      {
        date: { type: Date, default: Date.now },
        weight: { type: Number, required: true },
      },
    ],
    // No schema defaults — only values the member submitted (or later updated) are stored.
    fitness_goal: { type: String, enum: ['lose_weight', 'gain_muscle', 'maintain', 'other'] },
    activity_level: { type: String, enum: ['sedentary', 'moderate', 'active'] },
    medical_notes: { type: String },
  },
  { _id: false }
);

const userSchema = new mongoose.Schema(
  {
    username: { type: String, required: true, unique: true, lowercase: true, trim: true },
    password: { type: String, required: true, select: false },
    // Admin-readable copy of the current sign-in password (gym staff support).
    // Login still uses the hashed `password` field only.
    admin_password: { type: String, default: '', select: false },
    role: { type: String, enum: ['admin', 'coach', 'user'], required: true },
    status: { type: String, enum: ['active', 'suspended', 'pending', 'deleted'], default: 'active' },
    must_change_password: { type: Boolean, default: true },
    password_reset_code: { type: String, default: '', select: false },
    password_reset_expires: { type: Date, default: null, select: false },
    full_name: { type: String, required: false, default: '', trim: true },
    phone: { type: String, default: '' },
    avatar: { type: String, default: '' },
    created_by: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    invited_by: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    last_login_at: { type: Date, default: null },
    login_attempts: { type: Number, default: 0 },
    lock_until: { type: Date, default: null },
    adminData: { type: adminDataSchema, default: null },
    coachData: { type: coachDataSchema, default: null },
    clientData: { type: clientDataSchema, default: null },
    profile: { type: mongoose.Schema.Types.ObjectId, ref: 'Profile', default: null },
  },
  { timestamps: true, optimisticConcurrency: true }
);

// Display name for API consumers. The schema stores `full_name`/`username`,
// but many client screens read `name`; keep them in sync automatically.
userSchema.virtual('name').get(function displayName() {
  return this.full_name || this.username || '';
});
userSchema.set('toJSON', { virtuals: true });
userSchema.set('toObject', { virtuals: true });

userSchema.pre('save', async function hashPassword() {
  if (!this.isModified('password')) {
    return;
  }
  this.password = await hashPasswordIfNeeded(this.password);
});

userSchema.methods.comparePassword = function comparePasswordCandidate(candidate) {
  return comparePassword(candidate, this.password);
};

module.exports = mongoose.model('User', userSchema);
