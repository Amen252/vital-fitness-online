const DietPlan = require('../models/DietPlan');
const DietAdherence = require('../models/DietAdherence');
const Notification = require('../models/Notification');
const FitnessClass = require('../models/FitnessClass');
const {
  getMealsForDate,
  mealHasContent,
  mondayBasedDayOfWeek,
} = require('../utils/mealAdherenceUtils');
const {
  normalizeReminderTime,
  buildMealReminderPayload,
  pad2,
} = require('../utils/mealReminderUtils');
const { isDatabaseConnected } = require('../config/db');

const INTERVAL_MS = 60 * 1000;
/** In-process dedupe for the current day: `${userId}:${yyyy-mm-dd}:${mealKey}` */
const sentKeys = new Set();

function localDateKey(date = new Date()) {
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

function localHm(date = new Date()) {
  return `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

function startOfLocalDay(date = new Date()) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

function pruneSentKeys(todayKey) {
  for (const key of sentKeys) {
    if (!key.includes(`:${todayKey}:`)) sentKeys.delete(key);
  }
}

function mealDedupeKey(userId, todayKey, meal, hm) {
  const type = meal.type || 'snacks';
  const mealId = meal._id ? String(meal._id) : `${type}:${hm}:${String(meal.name || '').trim()}`;
  return `${userId}:${todayKey}:${mealId}`;
}

async function isMealAlreadyCompleted(userId, mealType, dayStart) {
  const adherence = await DietAdherence.findOne({
    user: userId,
    date: dayStart,
  })
    .select('mealAdherence dayCompleted')
    .lean();
  if (!adherence) return false;
  if (adherence.dayCompleted) return true;
  const row = (adherence.mealAdherence || []).find((m) => m.type === mealType);
  return Boolean(row?.followed);
}

async function processDietMealReminders() {
  if (!isDatabaseConnected()) return;

  const now = new Date();
  const todayKey = localDateKey(now);
  const hm = localHm(now);
  const dayStart = startOfLocalDay(now);
  pruneSentKeys(todayKey);

  // Active diet plans only — meal times live on DietPlan meals/days.
  const activePlans = await DietPlan.find({ status: 'active' })
    .select('coach client fitnessClass title meals days planType targetDayOfWeek')
    .lean();

  if (!activePlans.length) return;

  for (const plan of activePlans) {
    const meals = getMealsForDate(plan, now).filter((meal) => {
      if (!mealHasContent(meal)) return false;
      const time = normalizeReminderTime(meal.reminderTime);
      return time && time === hm;
    });
    if (!meals.length) continue;

    let userIds = [];
    if (plan.client) {
      userIds = [plan.client];
    } else if (plan.fitnessClass) {
      const fitnessClass = await FitnessClass.findById(plan.fitnessClass)
        .select('enrolledStudents')
        .lean();
      userIds = (fitnessClass?.enrolledStudents || []).map((id) => id);
    }

    for (const userId of userIds) {
      for (const meal of meals) {
        const type = meal.type || 'snacks';
        const dedupeKey = mealDedupeKey(userId, todayKey, meal, hm);
        if (sentKeys.has(dedupeKey)) continue;

        if (await isMealAlreadyCompleted(userId, type, dayStart)) {
          sentKeys.add(dedupeKey);
          continue;
        }

        const payload = buildMealReminderPayload(plan, meal, { dateKey: todayKey });

        const already = await Notification.findOne({
          user: userId,
          type: 'reminder',
          'data.kind': 'meal_reminder',
          'data.planId': payload.data.planId,
          'data.mealType': type,
          'data.dateKey': todayKey,
          'data.reminderTime': payload.data.reminderTime,
        })
          .select('_id')
          .lean();

        if (already) {
          sentKeys.add(dedupeKey);
          continue;
        }

        await Notification.create({
          user: userId,
          message: payload.message,
          type: payload.type,
          data: payload.data,
        });
        sentKeys.add(dedupeKey);
      }
    }
  }
}

function tickDietMealReminders() {
  processDietMealReminders().catch((error) => {
    console.error('Diet meal reminder job failed:', error.message);
  });
}

function startDietMealReminderJob() {
  tickDietMealReminders();
  setInterval(tickDietMealReminders, INTERVAL_MS);
  console.log('Diet meal reminder job started');
}

module.exports = {
  startDietMealReminderJob,
  processDietMealReminders,
  mondayBasedDayOfWeek,
};
