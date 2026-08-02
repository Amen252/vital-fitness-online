const MealLog = require('../models/MealLog');
const ActivityLog = require('../models/ActivityLog');
const WorkoutCompletion = require('../models/WorkoutCompletion');
const ScheduleCompletion = require('../models/ScheduleCompletion');
const { getMealsForDate } = require('./mealAdherenceUtils');

/** Moderate-intensity exercise estimate when no explicit burn is stored. */
const DEFAULT_KCAL_PER_MINUTE = 7;

const COUNTED_WORKOUT_STATUSES = new Set(['completed', 'pending_review']);

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

function dayKey(date) {
  const d = startOfDay(date);
  return d.getTime();
}

function estimateWorkoutCaloriesBurn(durationMinutes) {
  const mins = Number(durationMinutes);
  if (!Number.isFinite(mins) || mins <= 0) return 0;
  return Math.round(mins * DEFAULT_KCAL_PER_MINUTE);
}

function completionTimestamp(completion) {
  return completion.completedAt || completion.submittedAt || completion.createdAt;
}

function isCompletionOnDay(completion, dayStart, dayEnd) {
  if (!COUNTED_WORKOUT_STATUSES.has(completion.status)) return false;
  const when = completionTimestamp(completion);
  if (!when) return false;
  const t = new Date(when);
  return t >= dayStart && t < dayEnd;
}

function completionCalories(completion) {
  return estimateWorkoutCaloriesBurn(completion.durationMinutes);
}

/**
 * Sum calories from coach-plan meals marked as followed for a calendar day.
 * Returns null when the plan has no meals defined for that date.
 */
function computeCaloriesInFromDietPlan(plan, adherenceRecord, date = new Date()) {
  if (!plan) return null;
  const meals = getMealsForDate(plan, date);
  if (!meals.length) return null;

  const adherenceMap = new Map(
    (adherenceRecord?.mealAdherence || []).map((m) => [m.type, m]),
  );

  let total = 0;
  for (const meal of meals) {
    const record = adherenceMap.get(meal.type);
    if (record?.followed) {
      total += Number(meal.calories) || 0;
    }
  }
  return total;
}

async function computeCaloriesInFromMealLogs(userId, date = new Date()) {
  const today = startOfDay(date);
  const tomorrow = endOfDay(date);
  const logs = await MealLog.find({
    user: userId,
    date: { $gte: today, $lt: tomorrow },
  }).lean();
  return logs.reduce((sum, log) => sum + (Number(log.calories) || 0), 0);
}

/**
 * Calories In: coach-plan followed meals when a plan exists for the day,
 * otherwise manually logged meals.
 */
async function resolveCaloriesIn(userId, { plan, adherence, date = new Date() } = {}) {
  const planMeals = plan ? getMealsForDate(plan, date) : [];
  if (plan && planMeals.length) {
    return computeCaloriesInFromDietPlan(plan, adherence, date) ?? 0;
  }
  return computeCaloriesInFromMealLogs(userId, date);
}

async function fetchWorkoutCompletionsForRange(userId, rangeStart, rangeEnd) {
  const [exerciseCompletions, scheduleCompletions] = await Promise.all([
    WorkoutCompletion.find({ user: userId }).lean(),
    ScheduleCompletion.find({ user: userId }).lean(),
  ]);

  const inRange = (completion) => {
    const when = completionTimestamp(completion);
    if (!when || !COUNTED_WORKOUT_STATUSES.has(completion.status)) return false;
    const t = new Date(when);
    return t >= rangeStart && t < rangeEnd;
  };

  return [
    ...exerciseCompletions.filter(inRange),
    ...scheduleCompletions.filter(inRange),
  ];
}

async function computeCaloriesOut(userId, date = new Date()) {
  const today = startOfDay(date);
  const tomorrow = endOfDay(date);

  const [activities, workoutCompletions] = await Promise.all([
    ActivityLog.find({
      user: userId,
      date: { $gte: today, $lt: tomorrow },
      status: 'approved',
    }).lean(),
    fetchWorkoutCompletionsForRange(userId, today, tomorrow),
  ]);

  let total = activities.reduce((sum, a) => sum + (Number(a.caloriesBurned) || 0), 0);
  for (const completion of workoutCompletions) {
    if (isCompletionOnDay(completion, today, tomorrow)) {
      total += completionCalories(completion);
    }
  }
  return total;
}

/**
 * Build per-day calories-out totals (activities + completed workouts) for chart series.
 */
async function computeCaloriesOutByDay(userId, rangeStart, rangeEnd) {
  const start = startOfDay(rangeStart);
  const end = endOfDay(rangeEnd);

  const [activities, workoutCompletions] = await Promise.all([
    ActivityLog.find({
      user: userId,
      date: { $gte: start, $lt: end },
      status: 'approved',
    }).lean(),
    fetchWorkoutCompletionsForRange(userId, start, end),
  ]);

  const totals = new Map();

  for (const activity of activities) {
    const key = dayKey(activity.date);
    totals.set(key, (totals.get(key) || 0) + (Number(activity.caloriesBurned) || 0));
  }

  for (const completion of workoutCompletions) {
    const when = completionTimestamp(completion);
    if (!when) continue;
    const key = dayKey(when);
    totals.set(key, (totals.get(key) || 0) + completionCalories(completion));
  }

  return totals;
}

module.exports = {
  DEFAULT_KCAL_PER_MINUTE,
  startOfDay,
  endOfDay,
  estimateWorkoutCaloriesBurn,
  computeCaloriesInFromDietPlan,
  computeCaloriesInFromMealLogs,
  resolveCaloriesIn,
  computeCaloriesOut,
  computeCaloriesOutByDay,
  dayKey,
};
