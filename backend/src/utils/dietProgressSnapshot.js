const MealLog = require('../models/MealLog');
const WaterLog = require('../models/WaterLog');
const DietAdherence = require('../models/DietAdherence');
const ActivityLog = require('../models/ActivityLog');
const WorkoutSchedule = require('../models/WorkoutSchedule');
const ScheduleCompletion = require('../models/ScheduleCompletion');
const FitnessClass = require('../models/FitnessClass');
const {
  buildMealCompletionSummary,
  computeAverageAdherence,
} = require('./mealAdherenceUtils');
const { resolveCaloriesIn, computeCaloriesOut } = require('./calorieTrackingUtils');

const DEFAULT_WATER_TARGET_ML = 2000;

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

function countPlannedMeals(plan) {
  const { getPlannedMealTypes } = require('./mealAdherenceUtils');
  return getPlannedMealTypes(plan).length;
}

function countCompletedMeals(plan, adherence) {
  const summary = buildMealCompletionSummary(plan, adherence);
  return summary.completedMeals;
}

function computeDailyGoalPercent({ caloriesPct, waterPct, mealsPct, workoutsPct, hasAnyTarget }) {
  if (!hasAnyTarget) return 0;
  const parts = [caloriesPct, waterPct, mealsPct, workoutsPct].filter((v) => v != null);
  if (!parts.length) return 0;
  return Math.round(parts.reduce((sum, v) => sum + v, 0) / parts.length);
}

function pct(current, target) {
  if (!target || target <= 0) return 0;
  return Math.min(100, Math.round((current / target) * 100));
}

async function buildTodayProgressSnapshot(userId, plan) {
  const today = startOfDay();
  const tomorrow = endOfDay();

  const enrolledClasses = await FitnessClass.find({ enrolledStudents: userId }).select('_id').lean();
  const classIds = enrolledClasses.map((c) => c._id);

  const scheduleQuery = {
    status: { $in: ['scheduled', 'completed'] },
    startDateTime: { $gte: today, $lt: tomorrow },
    $or: [{ client: userId }],
  };
  if (classIds.length) {
    scheduleQuery.$or.push({ fitnessClass: { $in: classIds } });
  }

  const [
    mealLogs,
    waterLogs,
    adherence,
    activities,
    schedules,
  ] = await Promise.all([
    MealLog.find({ user: userId, date: { $gte: today, $lt: tomorrow } }).lean(),
    WaterLog.find({ user: userId, date: { $gte: today, $lt: tomorrow } }).lean(),
    DietAdherence.findOne({ user: userId, date: today }).lean(),
    ActivityLog.find({
      user: userId,
      date: { $gte: today, $lt: tomorrow },
      status: 'approved',
    }).lean(),
    WorkoutSchedule.find(scheduleQuery).select('_id status').lean(),
  ]);

  const caloriesConsumed = await resolveCaloriesIn(userId, { plan, adherence, date: today });
  const caloriesBurned = await computeCaloriesOut(userId, today);
  const targetCalories = plan?.dailyCalories || adherence?.targetCalories || 0;
  const waterMl = waterLogs.reduce((sum, log) => sum + (log.amountMl || 0), 0);
  const targetWaterMl = DEFAULT_WATER_TARGET_ML;

  const mealsPlanned = countPlannedMeals(plan);
  const mealSummary = buildMealCompletionSummary(plan, adherence);
  const mealsCompleted = mealSummary.completedMeals;

  const scheduleIds = schedules.map((s) => s._id);
  let workoutsCompleted = activities.length;
  let workoutsPlanned = workoutsCompleted > 0 ? workoutsCompleted : 0;

  if (scheduleIds.length) {
    const completions = await ScheduleCompletion.find({
      user: userId,
      workoutSchedule: { $in: scheduleIds },
      status: 'completed',
    }).lean();
    workoutsPlanned = scheduleIds.length;
    workoutsCompleted = Math.max(workoutsCompleted, completions.length);
  } else if (workoutsCompleted > 0) {
    workoutsPlanned = workoutsCompleted;
  }

  const caloriesPct = targetCalories > 0 ? pct(caloriesConsumed, targetCalories) : null;
  const waterPct = pct(waterMl, targetWaterMl);
  const mealsPct = mealsPlanned > 0 ? pct(mealsCompleted, mealsPlanned) : null;
  const workoutsPct = workoutsPlanned > 0 ? pct(workoutsCompleted, workoutsPlanned) : null;

  const dailyGoalPercent = computeDailyGoalPercent({
    caloriesPct,
    waterPct,
    mealsPct,
    workoutsPct,
    hasAnyTarget: targetCalories > 0 || mealsPlanned > 0 || workoutsPlanned > 0 || true,
  });

  const avgAdherenceToday = adherence?.adherencePercent ?? 0;
  const hasActivity = mealLogs.length > 0
    || waterLogs.length > 0
    || mealsCompleted > 0
    || workoutsCompleted > 0
    || adherence?.followedPlan;

  return {
    caloriesConsumed,
    caloriesBurned,
    targetCalories,
    waterMl,
    targetWaterMl,
    mealsCompleted,
    mealsPlanned,
    workoutsCompleted,
    workoutsPlanned,
    dailyGoalPercent: hasActivity ? dailyGoalPercent : 0,
    adherencePercent: mealSummary.dailyProgressPercent || adherence?.adherencePercent || 0,
    followedPlan: mealSummary.allCompleted,
    hasActivity,
    mealAdherence: adherence?.mealAdherence || [],
    mealSummary,
  };
}

module.exports = {
  buildTodayProgressSnapshot,
  countPlannedMeals,
  DEFAULT_WATER_TARGET_ML,
};
