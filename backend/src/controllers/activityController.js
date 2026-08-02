const ActivityLog = require('../models/ActivityLog');

async function createActivityLog(req, res) {
  try {
    const activityType = String(req.body.activityType || req.body.type || '').trim();
    const durationMinutes = Number(req.body.durationMinutes ?? req.body.duration_minutes);
    const caloriesBurned = Number(req.body.caloriesBurned ?? req.body.calories ?? 0);

    if (!activityType) {
      return res.status(400).json({ message: 'activityType is required' });
    }
    if (!Number.isFinite(durationMinutes) || durationMinutes <= 0) {
      return res.status(400).json({ message: 'durationMinutes must be a positive number' });
    }

    const payload = {
      activityType,
      durationMinutes,
      caloriesBurned: Number.isFinite(caloriesBurned) ? caloriesBurned : 0,
      sets: req.body.sets,
      user: req.user._id,
      // Members logging their own activity are trusted for progress tracking
      status: req.user.role === 'user' ? 'approved' : (req.body.status || 'pending'),
    };
    const log = await ActivityLog.create(payload);
    return res.status(201).json(log);
  } catch (error) {
    console.error('[ACTIVITY] createActivityLog:', error.message);
    return res.status(500).json({ message: 'Unable to log activity right now' });
  }
}

async function getActivityHistory(req, res) {
  const logs = await ActivityLog.find({ user: req.user._id, status: 'approved' }).sort({ date: -1 });
  return res.json(logs);
}

module.exports = { createActivityLog, getActivityHistory };
