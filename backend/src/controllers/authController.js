const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { randomInt } = require('crypto');
const { validationResult } = require('express-validator');
const User = require('../models/User');
const { sendEmail } = require('../utils/emailService');

const LOCK_TIME_MS = 15 * 60 * 1000; // 15 minutes
const MAX_FAILED_ATTEMPTS = 5;

function createToken(user) {
  return jwt.sign(
    { id: user._id, role: user.role, status: user.status },
    process.env.JWT_SECRET || 'dev-secret',
    { expiresIn: '7d' }
  );
}

function serializeUser(user) {
  const { enrichCoachUser } = require('../utils/coachProfile');

  const clientData = user.clientData
    ? {
        ...((typeof user.clientData.toObject === 'function')
          ? user.clientData.toObject()
          : { ...user.clientData }),
      }
    : user.clientData;

  if (clientData?.assigned_coach_id && typeof clientData.assigned_coach_id === 'object') {
    clientData.assigned_coach = {
      id: clientData.assigned_coach_id._id || clientData.assigned_coach_id.id,
      full_name: clientData.assigned_coach_id.full_name || '',
      username: clientData.assigned_coach_id.username || '',
      phone: clientData.assigned_coach_id.phone || '',
    };
    clientData.assigned_coach_id =
      clientData.assigned_coach_id._id || clientData.assigned_coach_id.id || clientData.assigned_coach_id;
  }

  const coachData = user.coachData
    ? ((typeof user.coachData.toObject === 'function')
      ? user.coachData.toObject()
      : { ...user.coachData })
    : user.coachData;

  const base = {
    id: user._id,
    username: user.username,
    // Mobile clients historically read `name` / `email`
    name: user.full_name || user.username,
    email: user.username,
    role: user.role,
    status: user.status,
    must_change_password: user.must_change_password,
    full_name: user.full_name,
    phone: user.phone,
    avatar: user.avatar,
    last_login_at: user.last_login_at,
    adminData: user.adminData,
    coachData,
    clientData,
  };

  // Always expose a normalized `profile` for coaches / applicants with coachData
  // so web + mobile Settings can render registration details.
  if (coachData || user.role === 'coach') {
    const enriched = enrichCoachUser({ ...user, coachData, phone: user.phone });
    base.profile = enriched.profile;
  }

  return base;
}

async function attachCoachApplicationStatus(serialized, userId) {
  try {
    const CoachApplication = require('../models/CoachApplication');
    const { enrichCoachUser } = require('../utils/coachProfile');
    const application = await CoachApplication.findOne({ user: userId }).lean();
    if (application) {
      serialized.coachApplicationStatus = application.status;
      serialized.coachApplicationReviewedAt = application.reviewedAt || null;
      // Keep coachData.approval_status aligned with the application review result.
      if (serialized.coachData && typeof serialized.coachData === 'object') {
        serialized.coachData = {
          ...serialized.coachData,
          approval_status: application.status,
        };
      }
      // Merge application fields into profile when coachData is incomplete
      // (older registrations) or still pending approval.
      if (serialized.coachData || application.status === 'pending') {
        const enriched = enrichCoachUser(
          {
            _id: serialized.id,
            full_name: serialized.full_name,
            username: serialized.username,
            phone: serialized.phone,
            avatar: serialized.avatar,
            status: serialized.status,
            role: serialized.role,
            coachData: serialized.coachData,
          },
          application,
        );
        serialized.profile = enriched.profile;
      }
    }
  } catch (error) {
    console.error('[AUTH] attachCoachApplicationStatus:', error.message);
  }
  return serialized;
}

async function login(req, res) {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { username, email, password } = req.body;
    const normalizedUsername = String(username || email || '').trim().toLowerCase();

    const user = await User.findOne({ username: normalizedUsername }).select('+password');

    if (!user) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    if (user.status === 'suspended' || user.status === 'deleted') {
      return res.status(403).json({
        message: user.status === 'deleted'
          ? 'This account has been deleted.'
          : 'This account has been suspended. Please contact support.',
      });
    }

    // Check rate limit lock-out
    if (user.lock_until && user.lock_until > Date.now()) {
      const remainingMin = Math.ceil((user.lock_until - Date.now()) / (60 * 1000));
      return res.status(423).json({
        message: `Account is temporarily locked due to too many failed attempts. Try again in ${remainingMin} minutes.`,
      });
    }

    const isMatch = await user.comparePassword(password);

    if (!isMatch) {
      user.login_attempts += 1;
      if (user.login_attempts >= MAX_FAILED_ATTEMPTS) {
        user.lock_until = new Date(Date.now() + LOCK_TIME_MS);
      }
      await user.save();

      if (user.login_attempts >= MAX_FAILED_ATTEMPTS) {
        return res.status(423).json({
          message: 'Too many failed login attempts. Your account has been locked for 15 minutes.',
        });
      }
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    // Login successful
    user.login_attempts = 0;
    user.lock_until = null;
    user.last_login_at = new Date();
    await user.save();

    const token = createToken(user);

    res.cookie('token', token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      maxAge: 7 * 24 * 60 * 60 * 1000,
    });

    return res.json({
      token,
      user: await attachCoachApplicationStatus(serializeUser(user), user._id),
    });
  } catch (error) {
    console.error('[AUTH] Login error:', error.message);
    const { isTransientDbError, markDatabaseUnavailable, scheduleConnectionRetry } = require('../config/db');
    if (isTransientDbError(error)) {
      markDatabaseUnavailable(req.app, error.message);
      scheduleConnectionRetry(req.app);
      return res.status(503).json({
        message:
          'Database is temporarily unavailable (MongoDB Atlas connection failed). '
          + 'If this continues, whitelist your current IP in Atlas Network Access, then try again.',
      });
    }
    return res.status(500).json({ message: 'Unable to sign in right now' });
  }
}

async function adminLogin(req, res) {
  // Direct to same login logic but verify role
  try {
    const { username, email, password } = req.body;
    const normalizedUsername = String(username || email || '').trim().toLowerCase();

    const user = await User.findOne({ username: normalizedUsername }).select('+password');

    if (!user) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    if (user.role !== 'admin') {
      return res.status(403).json({ message: 'Only admin accounts can access the Admin Dashboard' });
    }

    return login(req, res);
  } catch (error) {
    console.error('[AUTH] Admin login error:', error.message);
    return res.status(500).json({ message: 'Unable to sign in right now' });
  }
}

function logout(req, res) {
  res.clearCookie('token');
  return res.json({ message: 'Logged out successfully' });
}

async function me(req, res) {
  if (!req.user) {
    return res.status(401).json({ message: 'Authentication required' });
  }
  try {
    const user = await User.findById(req.user._id)
      .populate('clientData.assigned_coach_id', 'username full_name phone')
      .lean();
    if (!user) {
      return res.status(401).json({ message: 'Authentication required' });
    }
    return res.json({
      user: await attachCoachApplicationStatus(serializeUser(user), user._id),
    });
  } catch (error) {
    console.error('[AUTH] me error:', error.message);
    return res.status(500).json({ message: 'Unable to load profile' });
  }
}

async function changePassword(req, res) {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { currentPassword, newPassword } = req.body;

    if (!newPassword || newPassword.length < 6) {
      return res.status(400).json({ message: 'New password must be at least 6 characters long' });
    }

    const user = await User.findById(req.user._id).select('+password +admin_password');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const isMatch = await user.comparePassword(currentPassword);
    if (!isMatch) {
      return res.status(400).json({ message: 'Current password is incorrect' });
    }

    if (currentPassword === newPassword) {
      return res.status(400).json({ message: 'New password must be different from the current password' });
    }

    user.password = newPassword;
    user.admin_password = newPassword;
    user.must_change_password = false;
    await user.save();

    return res.json({ message: 'Password updated successfully' });
  } catch (error) {
    console.error('[AUTH] Change password error:', error.message);
    return res.status(500).json({ message: 'Unable to change password right now' });
  }
}

// Temporary placeholders for public registration if mobile app hits them
async function register(req, res) {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    const {
      username,
      password,
      full_name,
      phone = '',
      age,
      gender,
      height,
      weight,
      fitness_goal,
      activity_level,
      invite_code,
      ref,
    } = req.body;
    const normalizedUsername = String(username).trim().toLowerCase();
    const exists = await User.exists({ username: normalizedUsername });
    if (exists) return res.status(409).json({ message: 'Username already exists' });

    const InviteCode = require('../models/InviteCode');
    const Notification = require('../models/Notification');
    const rawInvite = String(invite_code || ref || '').trim().toUpperCase();
    let inviterId = null;
    let inviteDoc = null;
    if (rawInvite) {
      inviteDoc = await InviteCode.findOne({ code: rawInvite });
      if (!inviteDoc) {
        return res.status(400).json({ message: 'Invalid invite code' });
      }
      if (inviteDoc.max_uses != null && inviteDoc.uses >= inviteDoc.max_uses) {
        return res.status(400).json({ message: 'This invite code has reached its limit' });
      }
      inviterId = inviteDoc.owner_id;
    }

    // Persist only fields the member submitted — no invented profile defaults.
    const clientData = { assigned_coach_id: null };
    if (age !== undefined && age !== null && String(age).trim() !== '') {
      const parsedAge = Number(age);
      if (!Number.isNaN(parsedAge)) clientData.age = parsedAge;
    }
    if (gender === 'Female' || gender === 'Male') {
      clientData.gender = gender;
    } else if (typeof gender === 'string' && gender.trim()) {
      clientData.gender = gender.trim();
    }
    if (height !== undefined && height !== null && String(height).trim() !== '') {
      const parsedHeight = Number(height);
      if (!Number.isNaN(parsedHeight)) clientData.height = parsedHeight;
    }
    if (weight !== undefined && weight !== null && String(weight).trim() !== '') {
      const parsedWeight = Number(weight);
      if (!Number.isNaN(parsedWeight)) clientData.weight = parsedWeight;
    }
    if (['lose_weight', 'gain_muscle', 'maintain', 'other'].includes(fitness_goal)) {
      clientData.fitness_goal = fitness_goal;
    }
    if (['sedentary', 'moderate', 'active'].includes(activity_level)) {
      clientData.activity_level = activity_level;
    }

    // Role is always member for public registration — ignore any client-supplied role.
    if (req.body?.role != null && String(req.body.role).trim() !== '' && String(req.body.role).trim() !== 'user') {
      return res.status(400).json({
        message: 'Public registration only creates member accounts.',
        code: 'ROLE_NOT_ALLOWED',
      });
    }

    const user = await User.create({
      username: normalizedUsername,
      password,
      full_name: String(full_name).trim(),
      phone: String(phone || '').trim(),
      role: 'user',
      status: 'active',
      must_change_password: false,
      invited_by: inviterId,
      clientData,
    });

    if (inviteDoc) {
      inviteDoc.uses = (inviteDoc.uses || 0) + 1;
      await inviteDoc.save();
      try {
        const friendName = user.full_name?.split(/\s+/)[0] || user.username;
        await Notification.create({
          user: inviteDoc.owner_id,
          recipient_id: inviteDoc.owner_id,
          type: 'update',
          message: `${friendName} joined Vital Fitness using your invite. Nice work spreading the momentum!`,
          data: { invited_user_id: String(user._id) },
          read: false,
        });
      } catch (notifyError) {
        console.error('[AUTH] Invite notification:', notifyError.message);
      }
    }

    const token = createToken(user);
    const serialized = await attachCoachApplicationStatus(serializeUser(user), user._id);

    res.cookie('token', token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      maxAge: 7 * 24 * 60 * 60 * 1000,
    });

    return res.status(201).json({
      message: 'Account created. You can browse the available coaches and choose the coach you want.',
      token,
      user: serialized,
    });
  } catch (error) {
    if (error?.code === 11000) return res.status(409).json({ message: 'Username already exists' });
    console.error('[AUTH] Registration error:', error.message);
    return res.status(500).json({ message: 'Unable to create account right now' });
  }
}

async function registerCoach(req, res) {
  try {
    const CoachApplication = require('../models/CoachApplication');
    const Profile = require('../models/Profile');
    const { parseWorkingDays, validateWorkingDays } = require('../utils/workingDays');
    const { normalizeDayAvailability } = require('../utils/appointmentSlots');
    const { buildCoachDataFromApplication } = require('../utils/coachProfile');

    const {
      name,
      full_name,
      email,
      username,
      password,
      phone,
      age,
      location,
      yearsExperience,
      certifications,
      specialization,
      bio,
      experience,
      message,
      workingDays,
      appointmentDays,
      dayAvailability,
      appointmentDurationMinutes,
      certificateFiles,
    } = req.body;

    const identity = String(username || email || '')
      .trim()
      .toLowerCase();
    const fullName = String(name || full_name || '').trim();

    if (!identity) {
      return res.status(400).json({ message: 'Email / username is required' });
    }
    if (!fullName) {
      return res.status(400).json({ message: 'Full name is required' });
    }
    if (!password || String(password).length < 6) {
      return res.status(400).json({ message: 'Password must be at least 6 characters' });
    }

    const requiredFields = [
      ['phone', phone],
      ['age', age],
      ['location', location],
      ['yearsExperience', yearsExperience],
      ['certifications', certifications],
      ['specialization', specialization],
    ];
    // bio, experience, and message are optional and may be any length.
    for (const [field, value] of requiredFields) {
      if (value === undefined || value === null || String(value).trim() === '') {
        return res.status(400).json({ message: `${field} is required` });
      }
    }

    const { resolveCertificateFiles, requireCertificateFiles } = require('../utils/certificateUpload');
    let uploadedCertificates = [];
    try {
      requireCertificateFiles(certificateFiles);
      // Identity may be an email (no User ObjectId yet). certificateUpload only
      // runs ownership lookups when userId is a valid ObjectId.
      uploadedCertificates = await resolveCertificateFiles(certificateFiles, {
        userId: identity,
        expectedName: fullName,
      });
    } catch (certError) {
      return res.status(400).json({ message: certError.message, code: certError.code });
    }

    const workingDaysError = validateWorkingDays(workingDays);
    if (workingDaysError) {
      return res.status(400).json({ message: workingDaysError });
    }
    const appointmentDaysError = validateWorkingDays(appointmentDays);
    if (appointmentDaysError) {
      return res.status(400).json({
        message: appointmentDaysError.replace('working day', 'appointment day'),
      });
    }

    const availability = normalizeDayAvailability(
      appointmentDays,
      dayAvailability,
      appointmentDurationMinutes,
    );
    if (availability.error) {
      return res.status(400).json({ message: availability.error });
    }

    const exists = await User.exists({ username: identity });
    if (exists) {
      return res.status(409).json({ message: 'Username already exists' });
    }

    const parsedWorkingDays = parseWorkingDays(workingDays) || [];
    const parsedAppointmentDays = parseWorkingDays(appointmentDays) || [];
    const duration = Number(appointmentDurationMinutes) || 60;
    const daySlots = availability.value || [];

    const profileData = {
      age: Number(age) || null,
      phone: String(phone).trim(),
      location: String(location).trim(),
      yearsExperience: Number(yearsExperience) || 0,
      certifications: String(certifications).trim(),
      specialization: String(specialization).split(',').map((s) => s.trim()).filter(Boolean),
      bio: String(bio || '').trim(),
      experience: String(experience || '').trim(),
      workingDays: parsedWorkingDays,
      appointmentDays: parsedAppointmentDays,
      appointmentDurationMinutes: duration,
      dayAvailability: daySlots,
    };
    const profile = await Profile.create(profileData);

    const coachData = buildCoachDataFromApplication({
      approval_status: 'pending',
      phone: String(phone).trim(),
      age: Number(age),
      location: String(location).trim(),
      yearsExperience: Number(yearsExperience),
      certifications: String(certifications).trim(),
      specialization: String(specialization).trim(),
      bio: String(bio || '').trim(),
      experience: String(experience || '').trim(),
      workingDays: parsedWorkingDays,
      appointmentDays: parsedAppointmentDays,
      dayAvailability: daySlots,
      appointmentDurationMinutes: duration,
      workingHoursStart: daySlots[0]?.start || '09:00',
      workingHoursEnd: daySlots[0]?.end || '17:00',
      certificateFiles: uploadedCertificates,
    });

    // Applicants start as members with a pending coach application.
    // Admins approve via /admin/coach-applications (same flow as web).
    const user = await User.create({
      username: identity,
      password,
      admin_password: password,
      full_name: fullName,
      phone: String(phone).trim(),
      role: 'user',
      status: 'active',
      must_change_password: false,
      profile: profile._id,
      clientData: {
        age: Number(age) || null,
      },
      coachData,
    });

    await CoachApplication.create({
      user: user._id,
      phone: String(phone).trim(),
      age: Number(age),
      location: String(location).trim(),
      yearsExperience: Number(yearsExperience),
      certifications: String(certifications).trim(),
      certificateFiles: uploadedCertificates,
      specialization: String(specialization).trim(),
      bio: String(bio || '').trim(),
      experience: String(experience || '').trim(),
      message: String(message || '').trim(),
      workingDays: parsedWorkingDays,
      appointmentDays: parsedAppointmentDays,
      dayAvailability: daySlots,
      appointmentDurationMinutes: duration,
      status: 'pending',
    });

    const token = createToken(user);
    const serialized = await attachCoachApplicationStatus(serializeUser(user), user._id);

    res.cookie('token', token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      maxAge: 7 * 24 * 60 * 60 * 1000,
    });

    return res.status(201).json({
      message: 'Coach application submitted. An administrator will review it.',
      token,
      user: serialized,
    });
  } catch (error) {
    if (error?.code === 11000) {
      return res.status(409).json({ message: 'Username already exists' });
    }
    console.error('[AUTH] registerCoach error:', error.message);
    if (error.code === 'IMAGEKIT_NOT_CONFIGURED') {
      return res.status(503).json({ message: error.message, code: error.code });
    }
    if ([
      'INVALID_CERTIFICATES',
      'TOO_MANY_CERTIFICATES',
      'CERTIFICATE_TOO_LARGE',
      'CERTIFICATES_REQUIRED',
      'INVALID_FILE',
      'CERTIFICATE_NAME_REQUIRED',
      'CERTIFICATE_NAME_MISMATCH',
      'CERTIFICATE_OCR_FAILED',
    ].includes(error.code)) {
      return res.status(400).json({ message: error.message, code: error.code });
    }
    return res.status(500).json({ message: 'Unable to submit coach application right now' });
  }
}

/**
 * Upload a certificate image, then OCR-check the uploaded file for first + last name.
 * Body: { certificateFile | dataUrl | file, expectedName?, fileName? }
 * Returns CDN url on success so the client can attach the already-uploaded file.
 */
async function validateCoachCertificate(req, res) {
  try {
    const {
      isNameValidationEnabled,
      assertCertificateImageShowsName,
    } = require('../utils/certificateNameValidation');
    const {
      isFileDataUrl,
      mimeFromDataUrl,
      extensionFromDataUrl,
      uploadFileDataUrl,
    } = require('../utils/imageKit');

    const raw = req.body?.certificateFile ?? req.body?.dataUrl ?? req.body?.file ?? req.body?.url;
    const dataUrl = typeof raw === 'string'
      ? raw.trim()
      : String(raw?.dataUrl || raw?.url || raw?.file || '').trim();
    const expectedName = String(
      req.body?.expectedName || req.body?.name || req.body?.full_name || '',
    ).trim();
    const fileNameHint = String(req.body?.fileName || req.body?.name || '').trim();

    if (!dataUrl) {
      return res.status(400).json({
        message: 'Certificate image is required',
        code: 'INVALID_CERTIFICATES',
      });
    }
    if (!isFileDataUrl(dataUrl)) {
      return res.status(400).json({
        message: 'Certificate must be a JPG or PNG image',
        code: 'INVALID_CERTIFICATES',
      });
    }

    const mimeType = mimeFromDataUrl(dataUrl);
    const normalizedMime = mimeType === 'image/jpg' ? 'image/jpeg' : mimeType;
    if (!normalizedMime.startsWith('image/') || normalizedMime === 'application/pdf') {
      return res.status(400).json({
        message: 'Certificate must be a JPG or PNG photo that clearly shows your first and last name.',
        code: 'CERTIFICATE_NAME_REQUIRED',
      });
    }

    if (!expectedName) {
      return res.status(400).json({
        message: 'Enter your full name first, then upload a certificate that shows that name.',
        code: 'CERTIFICATE_NAME_REQUIRED',
      });
    }

    const ext = extensionFromDataUrl(dataUrl);
    const fileName = fileNameHint || `certificate.${ext}`;
    // 1) Upload to ImageKit first
    const url = await uploadFileDataUrl(dataUrl, {
      folder: '/vital/certificates',
      fileNamePrefix: 'cert_pending',
      fileName,
      tags: ['certificate', 'coach', 'pending-validation'],
    });

    // 2) OCR the uploaded image (skip only if validation disabled)
    let matchedName = null;
    if (isNameValidationEnabled()) {
      const result = await assertCertificateImageShowsName(url, {
        expectedName,
        index: 1,
      });
      matchedName = result.matchedName || null;
    }

    return res.json({
      ok: true,
      matchedName,
      url,
      fileName,
      mimeType: normalizedMime,
      uploadedAt: new Date().toISOString(),
    });
  } catch (error) {
    if ([
      'INVALID_CERTIFICATES',
      'CERTIFICATE_NAME_REQUIRED',
      'CERTIFICATE_NAME_MISMATCH',
      'CERTIFICATE_OCR_FAILED',
      'CERTIFICATE_TOO_LARGE',
      'INVALID_FILE',
      'IMAGEKIT_NOT_CONFIGURED',
      'IMAGEKIT_UPLOAD_FAILED',
    ].includes(error.code)) {
      const status = error.code === 'IMAGEKIT_NOT_CONFIGURED' ? 503 : 400;
      return res.status(status).json({ message: error.message, code: error.code });
    }
    console.error('[AUTH] validateCoachCertificate:', error.message);
    return res.status(500).json({ message: 'Unable to validate certificate right now' });
  }
}

async function forgotPassword(req, res) {
  try {
    const email = String(req.body.email || req.body.username || '')
      .trim()
      .toLowerCase();
    const genericMessage =
      'If an account exists for that email, a reset code has been sent.';

    if (!email || !email.includes('@')) {
      return res.status(400).json({ message: 'Please enter a valid email address' });
    }

    const user = await User.findOne({ username: email, role: { $ne: 'admin' } });
    if (!user) {
      return res.json({ message: genericMessage });
    }

    const code = String(randomInt(100000, 1000000));
    user.password_reset_code = code;
    user.password_reset_expires = new Date(Date.now() + 15 * 60 * 1000);
    await user.save();

    const displayName = user.full_name || user.username;
    const mailResult = await sendEmail({
      to: email,
      subject: 'Vital Fitness — Password reset code',
      text: [
        `Hi ${displayName},`,
        '',
        `Your password reset code is: ${code}`,
        'This code expires in 15 minutes.',
        '',
        'If you did not request a reset, you can ignore this email.',
        '',
        '— Vital Fitness',
      ].join('\n'),
      html: `
        <p>Hi <strong>${displayName}</strong>,</p>
        <p>Your password reset code is: <strong style="font-size:18px">${code}</strong></p>
        <p>This code expires in 15 minutes.</p>
        <p>If you did not request a reset, you can ignore this email.</p>
        <p>— Vital Fitness</p>
      `,
    });

    // When SMTP is not configured, surface the code so local/dev testing still works.
    if (mailResult?.simulated) {
      return res.json({
        message: `${genericMessage} Dev code: ${code}`,
        devCode: code,
      });
    }

    return res.json({ message: genericMessage });
  } catch (error) {
    console.error('[AUTH] forgotPassword:', error.message);
    return res.status(500).json({ message: 'Unable to start password reset right now' });
  }
}

async function resetPassword(req, res) {
  try {
    const email = String(req.body.email || req.body.username || '')
      .trim()
      .toLowerCase();
    const code = String(req.body.code || '').trim();
    const newPassword = String(req.body.newPassword || req.body.password || '');

    if (!email || !code || newPassword.length < 6) {
      return res.status(400).json({
        message: 'Email, reset code, and a new password (at least 6 characters) are required',
      });
    }

    const user = await User.findOne({ username: email, role: { $ne: 'admin' } }).select(
      '+password_reset_code +password',
    );
    if (
      !user
      || !user.password_reset_code
      || user.password_reset_code !== code
      || !user.password_reset_expires
      || user.password_reset_expires.getTime() < Date.now()
    ) {
      return res.status(400).json({ message: 'Invalid or expired reset code' });
    }

    user.password = newPassword;
    user.password_reset_code = '';
    user.password_reset_expires = null;
    user.must_change_password = false;
    await user.save();

    return res.json({ message: 'Password has been reset. You can sign in now.' });
  } catch (error) {
    console.error('[AUTH] resetPassword:', error.message);
    return res.status(500).json({ message: 'Unable to reset password right now' });
  }
}

module.exports = {
  login,
  adminLogin,
  me,
  logout,
  changePassword,
  register,
  registerCoach,
  validateCoachCertificate,
  forgotPassword,
  resetPassword,
};
