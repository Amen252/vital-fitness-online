const MealLog = require('../models/MealLog');
const nutritionalAgent = require('../agents/nutritionalAgent');

async function createDietLog(req, res) {
  const log = await MealLog.create({ ...req.body, user: req.user._id });
  return res.status(201).json(log);
}

async function getDietHistory(req, res) {
  const logs = await MealLog.find({ user: req.user._id }).sort({ date: -1 });
  const intakeSummary = nutritionalAgent.calculateDailyIntake(logs);
  return res.json({ logs, intakeSummary });
}

async function getSuggestedPlan(req, res) {
  const profile = req.user.profile;
  if (!profile) {
    return res.status(400).json({ message: 'Profile not found. Please complete onboarding.' });
  }
  const plan = nutritionalAgent.generateDietPlan(profile);
  return res.json(plan);
}

module.exports = { createDietLog, getDietHistory, getSuggestedPlan };

