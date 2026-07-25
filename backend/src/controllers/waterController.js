const WaterLog = require('../models/WaterLog');
const Notification = require('../models/Notification');
const CoachAssignment = require('../models/CoachAssignment');

async function createWaterLog(req, res) {
  const log = await WaterLog.create({ ...req.body, user: req.user._id });

  // Let the user's coach know how much water the client logged.
  try {
    const assignment = await CoachAssignment.findOne({
      user: req.user._id,
      status: 'active',
    }).lean();
    if (assignment?.coach) {
      const amount = Math.round(Number(req.body.amountMl) || log.amountMl || 0);
      await Notification.create({
        user: assignment.coach,
        message: `${req.user.name || 'A client'} logged ${amount}ml of water.`,
        type: 'update',
      });
    }
  } catch (err) {
    console.error('water coach notification:', err.message);
  }

  return res.status(201).json(log);
}

async function getWaterHistory(req, res) {
  const logs = await WaterLog.find({ user: req.user._id }).sort({ date: -1 });
  return res.json(logs);
}

module.exports = { createWaterLog, getWaterHistory };
