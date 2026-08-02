const DietPlan = require('../models/DietPlan');
const DietAdherence = require('../models/DietAdherence');
const Notification = require('../models/Notification');
const FitnessClass = require('../models/FitnessClass');
const {
  getMealsForDate,
  MEAL_LABELS,
  mondayBasedDayOfWeek,
} = require('../utils/mealAdherenceUtils');
const { isDatabaseConnected } = require('../config/db');

const INTERVAL_MS = 60 * 1000;
/** In-process dedupe for the current day: `${userId}:${yyyy-mm-dd}:${mealType}` */
const sentKeys = new Set();

function pad2(n) {
  return String(n).padStart(2, '0');
}

function localDateKey(date = new Date()) {
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

function localHm(date = new Date()) {
  return `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

function normalizeReminderTime(value) {
  const raw = String(value || '').trim();
  const match = raw.match(/^(\d{1,2}):(\d{2})$/);
  if (!match) return '';
  const h = Number(match[1]);
  const m = Number(match[2]);
  if (!Number.isFinite(h) || !Number.isFinite(m) || h < 0 || h > 23 || m < 0 || m > 59) {
    return '';
  }
  return `${pad2(h)}:${pad2(m)}`;
}

function pruneSentKeys(todayKey) {
  for (const key of sentKeys) {
    if (!key.includes(`:${todayKey}:`)) sentKeys.delete(key);
  }
}

async function processDietMealReminders() {
  if (!isDatabaseConnected()) return;

  const now = new Date();
  const todayKey = localDateKey(now);
  const hm = localHm(now);
  pruneSentKeys(todayKey);

  const activePlans = await DietPlan.find({ status: 'active' })
    .select('coach client fitnessClass title meals days planType targetDayOfWeek')
    .lean();

  if (!activePlans.length) return;

  for (const plan of activePlans) {
    const meals = getMealsForDate(plan, now).filter((meal) => {
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
        const dedupeKey = `${userId}:${todayKey}:${type}`;
        if (sentKeys.has(dedupeKey)) continue;

        const label = MEAL_LABELS[type] || type;
        const mealName = String(meal.name || label).trim() || label;
        const message = `Meal reminder: time for ${label} (${mealName}).`;

        const already = await Notification.findOne({
          user: userId,
          type: 'diet',
          message,
          createdAt: { $gte: new Date(now.getFullYear(), now.getMonth(), now.getDate()) },
        }).select('_id').lean();

        if (already) {
          sentKeys.add(dedupeKey);
          continue;
        }

        await Notification.create({
          user: userId,
          message,
          type: 'diet',
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
