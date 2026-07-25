const ActivityLog = require('../models/ActivityLog');
const MealLog = require('../models/MealLog');
const WaterLog = require('../models/WaterLog');
const User = require('../models/User');
const { buildSeries, sum } = require('../utils/progressMetrics');
const dataScientistAgent = require('../agents/dataScientistAgent');
const habitAgent = require('../agents/habitAgent');

async function getProgress(req, res) {
  const [meals, allActivities, water] = await Promise.all([
    MealLog.find({ user: req.user._id }).sort({ date: -1 }).limit(7),
    ActivityLog.find({ user: req.user._id }).sort({ date: -1 }).limit(7),
    WaterLog.find({ user: req.user._id }).sort({ date: -1 }).limit(7),
  ]);

  const approvedActivities = allActivities.filter((a) => a.status === 'approved');

  const caloriesIn = sum(meals, 'calories');
  const caloriesOut = sum(approvedActivities, 'caloriesBurned');
  const hydration = sum(water, 'amountMl');

  const analysis = dataScientistAgent.processLogsForCharts({
    meals,
    activities: approvedActivities,
    water,
  });
  const habitCompliance = habitAgent.generateComplianceReport({
    activities: approvedActivities,
    water,
    profile: req.user.profile,
  });

  const height = req.user.clientData?.height;
  const weight = req.user.clientData?.weight;
  let bmi = null;
  if (height && weight) {
    const m = height / 100;
    bmi = Math.round((weight / (m * m)) * 10) / 10;
  }

  return res.json({
    summary: {
      caloriesIn,
      caloriesOut,
      hydration,
      netCalories: analysis.dailyBalance,
      bmi: bmi ?? req.user.profile?.bmi ?? null,
      weightKg: weight ?? null,
      logCount: meals.length + approvedActivities.length + water.length,
    },
    trends: {
      caloriesIn: buildSeries(meals, 'date', 'calories'),
      caloriesOut: buildSeries(approvedActivities, 'date', 'caloriesBurned'),
      hydration: buildSeries(water, 'date', 'amountMl'),
    },
    reports: analysis.healthReport,
    compliance: habitCompliance,
    recentLogs: {
      meals: meals.slice(0, 5),
      activities: allActivities.slice(0, 5),
      water: water.slice(0, 5),
    },
  });
}

async function logWeight(req, res) {
  try {
    const weight = Number(req.body.weightKg ?? req.body.weight);
    if (!Number.isFinite(weight) || weight < 2 || weight > 500) {
      return res.status(400).json({ message: 'Enter a valid weight in kg' });
    }

    const user = await User.findById(req.user._id);
    if (!user) return res.status(404).json({ message: 'User not found' });
    if (!user.clientData) user.clientData = {};
    user.clientData.weight = weight;
    if (!Array.isArray(user.clientData.weight_history)) {
      user.clientData.weight_history = [];
    }
    user.clientData.weight_history.push({ date: new Date(), weight });
    await user.save();

    return res.status(201).json({
      weightKg: weight,
      weight_history: user.clientData.weight_history,
    });
  } catch (error) {
    console.error('logWeight:', error.message);
    return res.status(500).json({ message: 'Unable to log weight' });
  }
}

module.exports = { getProgress, logWeight };
