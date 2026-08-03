const MealLog = require('../models/MealLog');
const ActivityLog = require('../models/ActivityLog');
const WorkoutCompletion = require('../models/WorkoutCompletion');
const ScheduleCompletion = require('../models/ScheduleCompletion');
const { getMealsForDate, getPlannedMealTypes, mealHasContent } = require('./mealAdherenceUtils');

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
 * When coaches leave per-meal calories at 0 but set dailyCalories,
 * distribute the daily target evenly across planned meal types so progress
 * is not stuck at zero after check-offs.
 */
function fallbackCaloriesPerMealType(plan, date = new Date()) {
  const types = getPlannedMealTypes(plan, date);
  const daily = Number(plan?.dailyCalories) || 0;
  if (!types.length || daily <= 0) return 0;

  const meals = getMealsForDate(plan, date).filter(mealHasContent);
  const anyExplicit = meals.some((m) => (Number(m.calories) || 0) > 0);
  if (anyExplicit) return 0;

  return Math.round(daily / types.length);
}

function caloriesForMealType(type, meals, fallbackPerType) {
  const typeMeals = meals.filter((m) => m.type === type);
  const explicit = typeMeals.reduce((sum, m) => sum + (Number(m.calories) || 0), 0);
  if (explicit > 0) return explicit;
  return fallbackPerType;
}

function macrosForMealType(type, meals) {
  const typeMeals = meals.filter((m) => m.type === type);
  return typeMeals.reduce(
    (acc, m) => ({
      protein: acc.protein + (Number(m.protein) || 0),
      carbs: acc.carbs + (Number(m.carbs) || 0),
      fats: acc.fats + (Number(m.fats) || 0),
    }),
    { protein: 0, carbs: 0, fats: 0 },
  );
}

/**
 * Sum calories from coach-plan meals marked as followed for a calendar day.
 * Returns null when the plan has no meals defined for that date.
 */
function computeCaloriesInFromDietPlan(plan, adherenceRecord, date = new Date()) {
  if (!plan) return null;
  const meals = getMealsForDate(plan, date).filter(mealHasContent);
  if (!meals.length) return null;

  const plannedTypes = getPlannedMealTypes(plan, date);
  if (!plannedTypes.length) return null;

  const adherenceMap = new Map(
    (adherenceRecord?.mealAdherence || []).map((m) => [m.type, m]),
  );
  const fallbackPerType = fallbackCaloriesPerMealType(plan, date);

  let total = 0;
  for (const type of plannedTypes) {
    const record = adherenceMap.get(type);
    if (!record?.followed) continue;
    total += caloriesForMealType(type, meals, fallbackPerType);
  }
  return total;
}

/**
 * Sum protein / carbs / fats from followed plan meals (or MealLog when no plan meals).
 */
function computeNutritionFromDietPlan(plan, adherenceRecord, date = new Date()) {
  const empty = { protein: 0, carbs: 0, fats: 0 };
  if (!plan) return null;
  const meals = getMealsForDate(plan, date).filter(mealHasContent);
  if (!meals.length) return null;

  const plannedTypes = getPlannedMealTypes(plan, date);
  const adherenceMap = new Map(
    (adherenceRecord?.mealAdherence || []).map((m) => [m.type, m]),
  );

  const totals = { ...empty };
  for (const type of plannedTypes) {
    const record = adherenceMap.get(type);
    if (!record?.followed) continue;
    const macros = macrosForMealType(type, meals);
    totals.protein += macros.protein;
    totals.carbs += macros.carbs;
    totals.fats += macros.fats;
  }
  return totals;
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

async function computeNutritionFromMealLogs(userId, date = new Date()) {
  const today = startOfDay(date);
  const tomorrow = endOfDay(date);
  const logs = await MealLog.find({
    user: userId,
    date: { $gte: today, $lt: tomorrow },
  }).lean();
  return logs.reduce(
    (acc, log) => ({
      protein: acc.protein + (Number(log.protein) || 0),
      carbs: acc.carbs + (Number(log.carbs) || 0),
      fats: acc.fats + (Number(log.fats) || 0),
    }),
    { protein: 0, carbs: 0, fats: 0 },
  );
}

/**
 * Calories In: coach-plan followed meals when a plan exists for the day,
 * otherwise manually logged meals.
 */
async function resolveCaloriesIn(userId, { plan, adherence, date = new Date() } = {}) {
  const planMeals = plan ? getMealsForDate(plan, date).filter(mealHasContent) : [];
  if (plan && planMeals.length) {
    return computeCaloriesInFromDietPlan(plan, adherence, date) ?? 0;
  }
  return computeCaloriesInFromMealLogs(userId, date);
}

async function resolveNutrition(userId, { plan, adherence, date = new Date() } = {}) {
  const planMeals = plan ? getMealsForDate(plan, date).filter(mealHasContent) : [];
  if (plan && planMeals.length) {
    return computeNutritionFromDietPlan(plan, adherence, date) || { protein: 0, carbs: 0, fats: 0 };
  }
  return computeNutritionFromMealLogs(userId, date);
}

/**
 * Per-day calories-in for trend charts. Prefers live plan adherence when the
 * plan has meals for that day; otherwise uses MealLog totals.
 */
async function resolveCaloriesInByDay(userId, plan, rangeStart, rangeEnd, adherenceRecords = []) {
  const start = startOfDay(rangeStart);
  const end = endOfDay(rangeEnd);
  const DietAdherence = require('../models/DietAdherence');

  let records = adherenceRecords;
  if (!records?.length) {
    records = await DietAdherence.find({
      user: userId,
      date: { $gte: start, $lt: end },
    }).lean();
  }

  const adherenceByDay = new Map();
  for (const record of records) {
    adherenceByDay.set(dayKey(record.date), record);
  }

  const mealLogs = await MealLog.find({
    user: userId,
    date: { $gte: start, $lt: end },
  }).lean();

  const mealLogByDay = new Map();
  for (const log of mealLogs) {
    const key = dayKey(log.date);
    mealLogByDay.set(key, (mealLogByDay.get(key) || 0) + (Number(log.calories) || 0));
  }

  const totals = new Map();
  const cursor = new Date(start);
  while (cursor < end) {
    const key = dayKey(cursor);
    const planMeals = plan ? getMealsForDate(plan, cursor).filter(mealHasContent) : [];
    if (plan && planMeals.length) {
      const adherence = adherenceByDay.get(key);
      totals.set(key, computeCaloriesInFromDietPlan(plan, adherence, cursor) ?? 0);
    } else {
      totals.set(key, mealLogByDay.get(key) || 0);
    }
    cursor.setDate(cursor.getDate() + 1);
  }
  return totals;
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
  computeNutritionFromDietPlan,
  computeNutritionFromMealLogs,
  resolveCaloriesIn,
  resolveNutrition,
  resolveCaloriesInByDay,
  computeCaloriesOut,
  computeCaloriesOutByDay,
  fallbackCaloriesPerMealType,
  dayKey,
};
