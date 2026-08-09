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
/** Catch-up window so a late tick still fires reminders for the last N minutes. */
const LOOKBACK_MINUTES = 2;
/** In-process dedupe for the current day: `${userId}:${yyyy-mm-dd}:${mealKey}` */
const sentKeys = new Set();

/**
 * Wall-clock for meal reminders.
 * Prefer DIET_REMINDER_TZ (IANA), else process TZ / server local.
 * Coach-entered HH:MM values are interpreted in this timezone.
 */
function reminderTimeZone() {
  const tz = String(process.env.DIET_REMINDER_TZ || process.env.TZ || '').trim();
  return tz || undefined;
}

function partsInZone(date = new Date(), timeZone = reminderTimeZone()) {
  const opts = {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    ...(timeZone ? { timeZone } : {}),
  };
  const parts = new Intl.DateTimeFormat('en-CA', opts).formatToParts(date);
  const get = (type) => parts.find((p) => p.type === type)?.value;
  const year = Number(get('year'));
  const month = Number(get('month'));
  const day = Number(get('day'));
  let hour = Number(get('hour'));
  // Some engines emit "24" for midnight.
  if (hour === 24) hour = 0;
  const minute = Number(get('minute'));
  const weekday = String(get('weekday') || '').slice(0, 3);
  // Monday=0 … Sunday=6
  const weekdayMap = { Mon: 0, Tue: 1, Wed: 2, Thu: 3, Fri: 4, Sat: 5, Sun: 6 };
  const dayOfWeek = weekdayMap[weekday];
  return { year, month, day, hour, minute, dayOfWeek };
}

function localDateKey(date = new Date()) {
  const { year, month, day } = partsInZone(date);
  return `${year}-${pad2(month)}-${pad2(day)}`;
}

function localHm(date = new Date()) {
  const { hour, minute } = partsInZone(date);
  return `${pad2(hour)}:${pad2(minute)}`;
}

function hmToMinutes(hm) {
  const match = /^(\d{1,2}):(\d{2})$/.exec(String(hm || '').trim());
  if (!match) return null;
  return Number(match[1]) * 60 + Number(match[2]);
}

/** True when meal HH:MM equals now, or fell in the last LOOKBACK_MINUTES (same local day). */
function isReminderDue(mealHm, nowHm) {
  const mealMins = hmToMinutes(mealHm);
  const nowMins = hmToMinutes(nowHm);
  if (mealMins == null || nowMins == null) return false;
  if (mealMins === nowMins) return true;
  if (nowMins > mealMins && nowMins - mealMins <= LOOKBACK_MINUTES) return true;
  return false;
}

function startOfLocalDay(date = new Date()) {
  const { year, month, day } = partsInZone(date);
  // Construct a Date at local midnight for adherence day matching when TZ is process local.
  // When DIET_REMINDER_TZ differs from process TZ, store calendar key via dateKey on notifications
  // and parse Y-M-D as local components in logUserAdherence.
  return new Date(year, month - 1, day, 0, 0, 0, 0);
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

let dietReminderJobRunning = false;

async function processDietMealReminders() {
  if (!isDatabaseConnected()) return;
  if (dietReminderJobRunning) return;
  dietReminderJobRunning = true;

  try {
  const now = new Date();
  const todayKey = localDateKey(now);
  const hm = localHm(now);
  const dayStart = startOfLocalDay(now);
  const { dayOfWeek } = partsInZone(now);
  pruneSentKeys(todayKey);

  // Active diet plans only — meal times live on DietPlan meals/days.
  const activePlans = await DietPlan.find({ status: 'active' })
    .select('coach client fitnessClass title meals days planType targetDayOfWeek')
    .lean();

  if (!activePlans.length) return;

  for (const plan of activePlans) {
    const meals = getMealsForDate(plan, now, { dayOfWeek }).filter((meal) => {
      if (!mealHasContent(meal)) return false;
      const time = normalizeReminderTime(meal.reminderTime);
      return time && isReminderDue(time, hm);
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
        const reminderTime = normalizeReminderTime(meal.reminderTime);
        const dedupeKey = mealDedupeKey(userId, todayKey, meal, reminderTime);
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

        // Reserve before write to reduce duplicate races within the same process.
        sentKeys.add(dedupeKey);
        try {
          await Notification.create({
            user: userId,
            message: payload.message,
            type: payload.type,
            data: payload.data,
          });
        } catch (createErr) {
          if (createErr?.code !== 11000) {
            sentKeys.delete(dedupeKey);
            throw createErr;
          }
        }
      }
    }
  }
  } finally {
    dietReminderJobRunning = false;
  }
}

function tickDietMealReminders() {
  processDietMealReminders().catch((error) => {
    console.error('Diet meal reminder job failed:', error.message);
  });
}

function msUntilNextMinute() {
  const now = Date.now();
  return 60000 - (now % 60000) + 50;
}

function startDietMealReminderJob() {
  tickDietMealReminders();
  // Align to clock minutes so HH:MM matches reliably, then keep a 60s cadence.
  setTimeout(() => {
    tickDietMealReminders();
    setInterval(tickDietMealReminders, INTERVAL_MS);
  }, msUntilNextMinute());
  const tz = reminderTimeZone() || Intl.DateTimeFormat().resolvedOptions().timeZone || 'local';
  console.log(`Diet meal reminder job started (timezone: ${tz})`);
}

module.exports = {
  startDietMealReminderJob,
  processDietMealReminders,
  mondayBasedDayOfWeek,
  localDateKey,
  localHm,
  isReminderDue,
};
