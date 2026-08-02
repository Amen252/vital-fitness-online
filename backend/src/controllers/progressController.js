const ActivityLog = require('../models/ActivityLog');
const MealLog = require('../models/MealLog');
const WaterLog = require('../models/WaterLog');
const DietAdherence = require('../models/DietAdherence');
const User = require('../models/User');
const { buildSeries, sum } = require('../utils/progressMetrics');
const {
  resolveCaloriesIn,
  computeCaloriesOut,
  computeCaloriesOutByDay,
  dayKey,
} = require('../utils/calorieTrackingUtils');
const { resolveUserDietPlan } = require('./dietPlanController');
const dataScientistAgent = require('../agents/dataScientistAgent');
const habitAgent = require('../agents/habitAgent');

function startOfDay(date = new Date()) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

function endOfDay(date = new Date()) {
  const d = startOfDay(date);
  d.setDate(d.getDate() + 1);
  return d;
}

async function getProgress(req, res) {
  const today = startOfDay();
  const tomorrow = endOfDay();
  const weekStart = startOfDay();
  weekStart.setDate(weekStart.getDate() - 6);

  const [
    todayMeals,
    todayActivities,
    todayWater,
    weekMeals,
    weekActivities,
    weekWater,
    plan,
    todayAdherence,
    caloriesOutByDay,
  ] = await Promise.all([
    MealLog.find({ user: req.user._id, date: { $gte: today, $lt: tomorrow } }),
    ActivityLog.find({ user: req.user._id, date: { $gte: today, $lt: tomorrow } }),
    WaterLog.find({ user: req.user._id, date: { $gte: today, $lt: tomorrow } }),
    MealLog.find({ user: req.user._id, date: { $gte: weekStart } }).sort({ date: -1 }).limit(100),
    ActivityLog.find({ user: req.user._id, date: { $gte: weekStart } }).sort({ date: -1 }).limit(100),
    WaterLog.find({ user: req.user._id, date: { $gte: weekStart } }).sort({ date: -1 }).limit(100),
    resolveUserDietPlan(req.user._id),
    DietAdherence.findOne({ user: req.user._id, date: today }).lean(),
    computeCaloriesOutByDay(req.user._id, weekStart, tomorrow),
  ]);

  const [caloriesIn, caloriesOut] = await Promise.all([
    resolveCaloriesIn(req.user._id, { plan, adherence: todayAdherence, date: today }),
    computeCaloriesOut(req.user._id, today),
  ]);

  const approvedToday = todayActivities.filter((a) => a.status === 'approved');
  const approvedWeek = weekActivities.filter((a) => a.status === 'approved');

  const hydration = sum(todayWater, 'amountMl');

  const caloriesOutTrend = buildSeries(approvedWeek, 'date', 'caloriesBurned');
  for (const point of caloriesOutTrend) {
    const totalForDay = caloriesOutByDay.get(dayKey(point.date));
    if (totalForDay != null) point.value = totalForDay;
  }
  for (const [key, value] of caloriesOutByDay.entries()) {
    if (caloriesOutTrend.some((p) => dayKey(p.date) === key)) continue;
    caloriesOutTrend.push({ date: new Date(Number(key)), value });
  }
  caloriesOutTrend.sort((a, b) => new Date(a.date) - new Date(b.date));

  const analysis = dataScientistAgent.processLogsForCharts({
    meals: weekMeals,
    activities: approvedWeek,
    water: weekWater,
  });
  const habitCompliance = habitAgent.generateComplianceReport({
    activities: approvedWeek,
    water: weekWater,
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
      netCalories: caloriesIn - caloriesOut,
      bmi: bmi ?? req.user.profile?.bmi ?? null,
      weightKg: weight ?? null,
      logCount: todayMeals.length + approvedToday.length + todayWater.length,
    },
    trends: {
      caloriesIn: buildSeries(weekMeals, 'date', 'calories'),
      caloriesOut: caloriesOutTrend,
      hydration: buildSeries(weekWater, 'date', 'amountMl'),
    },
    reports: analysis.healthReport,
    compliance: habitCompliance,
    recentLogs: {
      meals: weekMeals.slice(0, 5),
      activities: weekActivities.slice(0, 5),
      water: weekWater.slice(0, 5),
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
