const ActivityLog = require('../models/ActivityLog');

async function createActivityLog(req, res) {
  const payload = {
    ...req.body,
    user: req.user._id,
    // Members logging their own activity are trusted for progress tracking
    status: req.user.role === 'user' ? 'approved' : (req.body.status || 'pending'),
  };
  const log = await ActivityLog.create(payload);
  return res.status(201).json(log);
}

async function getActivityHistory(req, res) {
  const logs = await ActivityLog.find({ user: req.user._id, status: 'approved' }).sort({ date: -1 });
  return res.json(logs);
}

module.exports = { createActivityLog, getActivityHistory };
