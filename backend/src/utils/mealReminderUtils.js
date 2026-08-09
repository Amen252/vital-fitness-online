const { MEAL_LABELS, mealHasContent } = require('./mealAdherenceUtils');

/** Only these meal types create reminder notifications. Snacks stay on the plan only. */
const REMINDER_MEAL_TYPES = ['breakfast', 'lunch', 'dinner'];

function pad2(n) {
  return String(n).padStart(2, '0');
}

function isReminderMealType(type) {
  return REMINDER_MEAL_TYPES.includes(String(type || '').toLowerCase());
}

/** Normalize wall-clock times like "8:00" → "08:00". Returns '' if invalid. */
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

function mealFoodSummary(meal) {
  const items = Array.isArray(meal?.foodItems)
    ? meal.foodItems.map((item) => String(item || '').trim()).filter(Boolean)
    : [];
  if (items.length) return items.join(', ');
  return String(meal?.description || '').trim();
}

function mealNutritionSummary(meal) {
  const parts = [];
  const calories = Number(meal?.calories) || 0;
  const protein = Number(meal?.protein) || 0;
  const carbs = Number(meal?.carbs) || 0;
  const fats = Number(meal?.fats) || 0;
  if (calories > 0) parts.push(`${calories} kcal`);
  if (protein > 0) parts.push(`P ${protein}g`);
  if (carbs > 0) parts.push(`C ${carbs}g`);
  if (fats > 0) parts.push(`F ${fats}g`);
  return parts.join(' · ');
}

function mealCoachNotes(meal) {
  const notes = [
    String(meal?.prepInstructions || '').trim(),
    String(meal?.mealNotes || meal?.notes || '').trim(),
  ].filter(Boolean);
  return notes.join(' · ');
}

/**
 * Build in-app reminder message + structured data for Notification.data.
 * Uses existing DietPlan meal fields only (no separate reminder collection).
 */
function buildMealReminderPayload(plan, meal, { dateKey } = {}) {
  const type = meal?.type || 'snacks';
  const label = MEAL_LABELS[type] || type;
  const mealName = String(meal?.name || label).trim() || label;
  const reminderTime = normalizeReminderTime(meal?.reminderTime);
  const food = mealFoodSummary(meal);
  const nutrition = mealNutritionSummary(meal);
  const coachNotes = mealCoachNotes(meal);
  const portionSize = String(meal?.portionSize || '').trim();

  const lines = [
    `Meal reminder: ${mealName}`,
    reminderTime ? `Time: ${reminderTime}` : null,
    food ? `Food: ${food}` : null,
    portionSize ? `Portion: ${portionSize}` : null,
    nutrition ? `Nutrition: ${nutrition}` : null,
    coachNotes ? `Notes: ${coachNotes}` : null,
  ].filter(Boolean);

  return {
    message: lines.join('\n'),
    type: 'reminder',
    data: {
      kind: 'meal_reminder',
      screen: 'diet',
      planId: plan?._id ? String(plan._id) : null,
      planTitle: plan?.title || '',
      mealId: meal?._id ? String(meal._id) : null,
      mealType: type,
      mealLabel: label,
      mealName,
      reminderTime,
      foodItems: Array.isArray(meal?.foodItems)
        ? meal.foodItems.map((item) => String(item || '').trim()).filter(Boolean)
        : [],
      description: String(meal?.description || '').trim(),
      portionSize,
      calories: Number(meal?.calories) || 0,
      protein: Number(meal?.protein) || 0,
      carbs: Number(meal?.carbs) || 0,
      fats: Number(meal?.fats) || 0,
      prepInstructions: String(meal?.prepInstructions || '').trim(),
      mealNotes: String(meal?.mealNotes || meal?.notes || '').trim(),
      dateKey: dateKey || null,
    },
  };
}

/** Reminder-eligible meals that have content but are missing a valid HH:MM time. */
function findMealsMissingReminderTime(meals = []) {
  return (meals || [])
    .filter(
      (meal) =>
        isReminderMealType(meal?.type) &&
        mealHasContent(meal) &&
        !normalizeReminderTime(meal.reminderTime),
    )
    .map((meal) => MEAL_LABELS[meal.type] || meal.name || meal.type);
}

/**
 * For active plans, Breakfast/Lunch/Dinner must have a meal time so the cron can fire.
 * Snacks are diet-plan content only and are never required for reminders.
 */
function validateActivePlanMealTimes(structure) {
  if (!structure) return null;
  let meals = [];
  if (structure.planType === 'weekly') {
    const flat = (structure.meals || []).filter((m) => mealHasContent(m));
    const fromDays = (structure.days || []).flatMap((d) =>
      (d.meals || []).filter((m) => mealHasContent(m)),
    );
    meals = flat.length ? [...flat, ...fromDays] : fromDays;
  } else {
    meals = (structure.meals || []).filter((m) => mealHasContent(m));
  }

  const missing = findMealsMissingReminderTime(meals);
  if (!missing.length) return null;
  return {
    error: `Set a Meal Time for Breakfast, Lunch, and Dinner so reminders can fire: ${[...new Set(missing)].join(', ')}.`,
  };
}

module.exports = {
  REMINDER_MEAL_TYPES,
  isReminderMealType,
  pad2,
  normalizeReminderTime,
  mealFoodSummary,
  mealNutritionSummary,
  mealCoachNotes,
  buildMealReminderPayload,
  findMealsMissingReminderTime,
  validateActivePlanMealTimes,
};
