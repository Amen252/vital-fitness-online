const ShareCard = require('../models/ShareCard');
const InviteCode = require('../models/InviteCode');
const User = require('../models/User');
const ActivityLog = require('../models/ActivityLog');
const MealLog = require('../models/MealLog');
const WaterLog = require('../models/WaterLog');
const WorkoutCompletion = require('../models/WorkoutCompletion');
const DietAdherence = require('../models/DietAdherence');
const { sum } = require('../utils/progressMetrics');

function publicBaseUrl(req) {
  const configured = (
    process.env.PUBLIC_WEB_URL ||
    process.env.CLIENT_URL ||
    ''
  ).replace(/\/$/, '');
  if (configured) return configured;
  if (req?.headers?.origin) return String(req.headers.origin).replace(/\/$/, '');
  return 'http://127.0.0.1:5174';
}

function firstName(fullName, username) {
  const name = String(fullName || '').trim();
  if (name) return name.split(/\s+/)[0];
  return username || 'Member';
}

function daysAgo(n) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  d.setHours(0, 0, 0, 0);
  return d;
}

async function buildProgressPayload(user) {
  const since = daysAgo(7);
  const [meals, activities, water, completions, adherence, coach] = await Promise.all([
    MealLog.find({ user: user._id, date: { $gte: since } }).lean(),
    ActivityLog.find({ user: user._id, date: { $gte: since }, status: 'approved' }).lean(),
    WaterLog.find({ user: user._id, date: { $gte: since } }).lean(),
    WorkoutCompletion.find({
      user: user._id,
      createdAt: { $gte: since },
      status: 'completed',
    }).lean(),
    DietAdherence.find({ user: user._id, date: { $gte: since } }).lean(),
    user.clientData?.assigned_coach_id
      ? User.findById(user.clientData.assigned_coach_id).select('full_name username').lean()
      : null,
  ]);

  const avgAdherence = adherence.length
    ? Math.round(adherence.reduce((s, a) => s + (a.adherencePercent || 0), 0) / adherence.length)
    : 0;

  const weight = user.clientData?.weight ?? null;
  const height = user.clientData?.height ?? null;
  let bmi = null;
  if (weight && height) {
    const m = height / 100;
    bmi = Math.round((weight / (m * m)) * 10) / 10;
  }

  return {
    displayName: firstName(user.full_name, user.username),
    coachedBy: coach ? firstName(coach.full_name, coach.username) : null,
    metrics: {
      workoutsCompleted: completions.length,
      dietAdherencePercent: avgAdherence,
      waterMl: sum(water, 'amountMl'),
      caloriesIn: sum(meals, 'calories'),
      caloriesOut: sum(activities, 'caloriesBurned'),
      bmi,
      weightKg: weight,
    },
    periodLabel: 'Last 7 days',
  };
}

async function buildWeeklyPayload(user) {
  const base = await buildProgressPayload(user);
  return {
    ...base,
    headline: 'Weekly win',
    periodLabel: 'This week',
  };
}

async function buildWorkoutPayload(user, body = {}) {
  const coach = user.clientData?.assigned_coach_id
    ? await User.findById(user.clientData.assigned_coach_id).select('full_name username').lean()
    : null;

  const title = String(body.title || body.workoutTitle || 'Workout').trim() || 'Workout';
  const level = body.level ? String(body.level) : null;

  return {
    displayName: firstName(user.full_name, user.username),
    coachedBy: coach ? firstName(coach.full_name, coach.username) : null,
    workoutTitle: title,
    level,
    completedAt: new Date().toISOString(),
    headline: 'Just finished a workout',
  };
}

async function createShareCard(req, res) {
  try {
    const type = String(req.body.type || 'progress').toLowerCase();
    if (!['progress', 'workout', 'weekly'].includes(type)) {
      return res.status(400).json({ message: 'type must be progress, workout, or weekly' });
    }

    const user = await User.findById(req.user._id).lean();
    if (!user) return res.status(401).json({ message: 'Authentication required' });

    let payload;
    if (type === 'workout') {
      payload = await buildWorkoutPayload(user, req.body);
    } else if (type === 'weekly') {
      payload = await buildWeeklyPayload(user);
    } else {
      payload = await buildProgressPayload(user);
    }

    // Strip anything sensitive that might sneak in
    const safePayload = JSON.parse(JSON.stringify(payload));
    for (const key of ['phone', 'medical_notes', 'email', 'username', 'password', 'avatar']) {
      delete safePayload[key];
    }
    if (safePayload.metrics && typeof safePayload.metrics === 'object') {
      delete safePayload.metrics.phone;
      delete safePayload.metrics.medical_notes;
    }

    const expires = new Date();
    expires.setDate(expires.getDate() + 30);

    const token = ShareCard.createToken();
    const card = await ShareCard.create({
      token,
      user_id: user._id,
      type,
      payload: safePayload,
      expires_at: expires,
    });

    const url = `${publicBaseUrl(req)}/s/${card.token}`;
    return res.status(201).json({
      token: card.token,
      type: card.type,
      url,
      path: `/s/${card.token}`,
      expiresAt: card.expires_at,
      payload: card.payload,
    });
  } catch (error) {
    console.error('createShareCard:', error.message);
    return res.status(500).json({ message: 'Unable to create share card' });
  }
}

async function getShareCard(req, res) {
  try {
    const card = await ShareCard.findOne({ token: req.params.token }).lean();
    if (!card) {
      return res.status(404).json({ message: 'Share card not found' });
    }
    if (card.expires_at && new Date(card.expires_at) < new Date()) {
      return res.status(410).json({ message: 'This share link has expired' });
    }

    ShareCard.updateOne({ _id: card._id }, { $inc: { view_count: 1 } }).catch(() => {});

    let inviteCode = null;
    try {
      const invite = await InviteCode.findOne({ owner_id: card.user_id }).lean();
      inviteCode = invite?.code || null;
    } catch {
      inviteCode = null;
    }

    return res.json({
      token: card.token,
      type: card.type,
      payload: card.payload,
      expiresAt: card.expires_at,
      inviteCode,
      joinUrl: inviteCode
        ? `${publicBaseUrl(req)}/register?ref=${encodeURIComponent(inviteCode)}`
        : `${publicBaseUrl(req)}/register`,
      joinPath: inviteCode
        ? `/register?ref=${encodeURIComponent(inviteCode)}`
        : '/register',
    });
  } catch (error) {
    console.error('getShareCard:', error.message);
    return res.status(500).json({ message: 'Unable to load share card' });
  }
}

async function getOrCreateInvite(ownerId) {
  let invite = await InviteCode.findOne({ owner_id: ownerId });
  if (invite) return invite;

  for (let attempt = 0; attempt < 5; attempt += 1) {
    try {
      invite = await InviteCode.create({
        code: InviteCode.generateCode(),
        owner_id: ownerId,
        uses: 0,
      });
      return invite;
    } catch (error) {
      if (error?.code !== 11000) throw error;
    }
  }
  throw new Error('Unable to generate invite code');
}

async function getMyInvite(req, res) {
  try {
    const invite = await getOrCreateInvite(req.user._id);
    const code = invite.code;
    return res.json({
      code,
      uses: invite.uses,
      maxUses: invite.max_uses,
      url: `${publicBaseUrl(req)}/register?ref=${encodeURIComponent(code)}`,
      shareUrl: `${publicBaseUrl(req)}/register?ref=${encodeURIComponent(code)}`,
      path: `/register?ref=${encodeURIComponent(code)}`,
    });
  } catch (error) {
    console.error('getMyInvite:', error.message);
    return res.status(500).json({ message: 'Unable to load invite link' });
  }
}

async function getInviteStats(req, res) {
  try {
    const invite = await getOrCreateInvite(req.user._id);
    return res.json({
      code: invite.code,
      uses: invite.uses,
      maxUses: invite.max_uses,
    });
  } catch (error) {
    console.error('getInviteStats:', error.message);
    return res.status(500).json({ message: 'Unable to load invite stats' });
  }
}

module.exports = {
  createShareCard,
  getShareCard,
  getMyInvite,
  getInviteStats,
  getOrCreateInvite,
  publicBaseUrl,
};
