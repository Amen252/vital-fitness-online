const WaterLog = require('../models/WaterLog');
const Notification = require('../models/Notification');
const CoachAssignment = require('../models/CoachAssignment');

async function createWaterLog(req, res) {
  try {
    const amountMl = Number(req.body.amountMl ?? req.body.amount_ml);
    if (!Number.isFinite(amountMl) || amountMl <= 0) {
      return res.status(400).json({ message: 'amountMl must be a positive number' });
    }

    const log = await WaterLog.create({ amountMl, user: req.user._id });

    // Let the user's coach know how much water the client logged.
    try {
      const assignment = await CoachAssignment.findOne({
        user: req.user._id,
        status: 'active',
      }).lean();
      if (assignment?.coach) {
        const amount = Math.round(amountMl);
        await Notification.create({
          user: assignment.coach,
          message: `${req.user.full_name || req.user.username || 'A client'} logged ${amount}ml of water.`,
          type: 'update',
        });
      }
    } catch (err) {
      console.error('water coach notification:', err.message);
    }

    return res.status(201).json(log);
  } catch (error) {
    console.error('[WATER] createWaterLog:', error.message);
    return res.status(500).json({ message: 'Unable to log water right now' });
  }
}

async function getWaterHistory(req, res) {
  const logs = await WaterLog.find({ user: req.user._id }).sort({ date: -1 });
  return res.json(logs);
}

module.exports = { createWaterLog, getWaterHistory };
