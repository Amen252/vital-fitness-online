const MEAL_TYPES = ['breakfast', 'lunch', 'dinner', 'snacks'];

const MEAL_LABELS = {
  breakfast: 'Breakfast',
  lunch: 'Lunch',
  dinner: 'Dinner',
  snacks: 'Snacks',
};

const DAY_NAMES = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/** Monday = 0 … Sunday = 6 (matches weekly workout plans). */
function mondayBasedDayOfWeek(date = new Date()) {
  const js = new Date(date).getDay();
  return js === 0 ? 6 : js - 1;
}

function mealHasContent(meal) {
  const name = String(meal?.name || '').trim();
  const description = String(meal?.description || '').trim();
  return name.length > 0 || description.length > 0;
}

/** Resolve meals for a calendar date from single-day or weekly plans. */
function getMealsForDate(plan, date = new Date()) {
  if (!plan) return [];
  const dow = mondayBasedDayOfWeek(date);
  if (plan.planType === 'weekly' && Array.isArray(plan.days) && plan.days.length) {
    const day = plan.days.find((d) => Number(d.dayOfWeek) === dow);
    return Array.isArray(day?.meals) ? day.meals : [];
  }
  // Single-day plan locked to a specific weekday
  if (
    plan.planType === 'single_day'
    && plan.targetDayOfWeek != null
    && Number.isFinite(Number(plan.targetDayOfWeek))
    && Number(plan.targetDayOfWeek) !== dow
  ) {
    return [];
  }
  return Array.isArray(plan.meals) ? plan.meals : [];
}

function getPlannedMealTypes(plan, date = new Date()) {
  const meals = getMealsForDate(plan, date);
  if (!meals.length) return [];
  const types = [];
  const seen = new Set();
  for (const meal of meals) {
    if (mealHasContent(meal) && MEAL_TYPES.includes(meal.type) && !seen.has(meal.type)) {
      seen.add(meal.type);
      types.push(meal.type);
    }
  }
  return types;
}

function applySingleMealToggle(existingRecord, mealType, followed, plan, date = new Date()) {
  const plannedTypes = getPlannedMealTypes(plan, date);
  if (!plannedTypes.includes(mealType)) {
    return existingRecord?.mealAdherence || [];
  }

  const existing = normalizeMealAdherence(existingRecord, existingRecord?.mealAdherence || [], plan, date);
  return existing.map((meal) => {
    if (meal.type !== mealType) return meal;
    const isFollowed = !!followed;
    return {
      type: mealType,
      followed: isFollowed,
      notes: meal.notes || '',
      completedAt: isFollowed
        ? (meal.followed && meal.completedAt ? meal.completedAt : new Date())
        : null,
    };
  });
}

function normalizeMealAdherence(existingRecord, incomingMeals, plan, date = new Date()) {
  const plannedTypes = getPlannedMealTypes(plan, date);
  const existingMap = new Map((existingRecord?.mealAdherence || []).map((m) => [m.type, m]));
  const incomingMap = new Map((incomingMeals || []).map((m) => [m.type, m]));

  return plannedTypes.map((type) => {
    const inc = incomingMap.get(type);
    const prev = existingMap.get(type);

    if (inc) {
      const followed = !!inc.followed;
      let completedAt = null;
      if (followed) {
        completedAt = prev?.followed && prev?.completedAt
          ? prev.completedAt
          : new Date();
      }
      return {
        type,
        followed,
        notes: inc.notes || prev?.notes || '',
        completedAt,
      };
    }

    if (prev) {
      return {
        type,
        followed: !!prev.followed,
        notes: prev.notes || '',
        completedAt: prev.followed ? (prev.completedAt || null) : null,
      };
    }

    return { type, followed: false, notes: '', completedAt: null };
  });
}

function buildMealCompletionSummary(plan, adherence, date = new Date()) {
  const plannedTypes = getPlannedMealTypes(plan, date);
  const adherenceMap = new Map((adherence?.mealAdherence || []).map((m) => [m.type, m]));

  const meals = plannedTypes.map((type) => {
    const record = adherenceMap.get(type);
    const completed = !!record?.followed;
    return {
      type,
      label: MEAL_LABELS[type] || type,
      completed,
      completedAt: completed ? (record?.completedAt || null) : null,
    };
  });

  const mealsPlanned = meals.length;
  const completedMeals = meals.filter((m) => m.completed).length;
  const missedMeals = mealsPlanned - completedMeals;
  const dailyProgressPercent = mealsPlanned > 0
    ? Math.round((completedMeals / mealsPlanned) * 100)
    : 0;
  const allCompleted = mealsPlanned > 0 && completedMeals === mealsPlanned;

  return {
    meals,
    mealsPlanned,
    completedMeals,
    missedMeals,
    dailyProgressPercent,
    allCompleted,
  };
}

async function computeAverageAdherence(DietAdherence, userId, days = 7) {
  const since = new Date();
  since.setDate(since.getDate() - days);
  since.setHours(0, 0, 0, 0);

  const records = await DietAdherence.find({
    user: userId,
    date: { $gte: since },
  }).lean();

  if (!records.length) return 0;
  const total = records.reduce((sum, r) => sum + (r.adherencePercent || 0), 0);
  return Math.round(total / records.length);
}

function startOfLocalDay(date = new Date()) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

/** Calendar date for a Monday-based weekday (0=Mon…6=Sun) in the week of `refDate`. */
function dateForMondayBasedDay(dayOfWeek, refDate = new Date()) {
  const dow = Number(dayOfWeek);
  if (!Number.isFinite(dow) || dow < 0 || dow > 6) return null;
  const today = startOfLocalDay(refDate);
  const todayDow = mondayBasedDayOfWeek(today);
  const result = new Date(today);
  result.setDate(today.getDate() + (dow - todayDow));
  return result;
}

function isDayCompletedRecord(record) {
  if (!record) return false;
  if (record.dayCompleted === true) return true;
  if (record.followedPlan === true && (record.adherencePercent || 0) >= 100) return true;
  return false;
}

/**
 * Build Mon–Sun completion status for the week containing `refDate`.
 * Uses DietAdherence rows keyed by calendar date.
 */
function buildWeekDayCompletionSummary(adherenceRecords = [], refDate = new Date()) {
  const byTime = new Map();
  for (const record of adherenceRecords || []) {
    const key = startOfLocalDay(record.date).getTime();
    byTime.set(key, record);
  }

  const days = [];
  let completedDays = 0;
  for (let i = 0; i < 7; i += 1) {
    const date = dateForMondayBasedDay(i, refDate);
    const record = byTime.get(date.getTime());
    const completed = isDayCompletedRecord(record);
    if (completed) completedDays += 1;
    days.push({
      dayOfWeek: i,
      dayName: DAY_NAMES[i],
      date: date.toISOString(),
      completed,
      completedAt: completed ? (record?.completedAt || null) : null,
      adherencePercent: record?.adherencePercent || (completed ? 100 : 0),
      isToday: mondayBasedDayOfWeek(refDate) === i,
      mealAdherence: record?.mealAdherence || [],
    });
  }

  return {
    days,
    daysPlanned: 7,
    completedDays,
    missedDays: 7 - completedDays,
    weeklyProgressPercent: Math.round((completedDays / 7) * 100),
    allDaysCompleted: completedDays === 7,
  };
}

/** Merge planned B/L/D/Snacks per weekday with adherence check-offs (coach/user week views). */
function enrichWeekCompletionWithPlannedMeals(plan, weekSummary, refDate = new Date()) {
  if (!plan || plan.planType !== 'weekly' || !weekSummary?.days) return weekSummary;
  const days = weekSummary.days.map((day) => {
    const date = dateForMondayBasedDay(day.dayOfWeek, refDate);
    const plannedTypes = getPlannedMealTypes(plan, date);
    const adherenceMap = new Map((day.mealAdherence || []).map((m) => [m.type, m]));
    const mealAdherence = plannedTypes.map((type) => {
      const record = adherenceMap.get(type);
      const followed = !!record?.followed;
      return {
        type,
        label: MEAL_LABELS[type],
        followed,
        completed: followed,
        notes: record?.notes || '',
        completedAt: followed ? (record?.completedAt || null) : null,
      };
    });
    return { ...day, mealAdherence };
  });
  return { ...weekSummary, days };
}

module.exports = {
  MEAL_TYPES,
  MEAL_LABELS,
  DAY_NAMES,
  mondayBasedDayOfWeek,
  mealHasContent,
  getMealsForDate,
  getPlannedMealTypes,
  normalizeMealAdherence,
  applySingleMealToggle,
  buildMealCompletionSummary,
  computeAverageAdherence,
  startOfLocalDay,
  dateForMondayBasedDay,
  isDayCompletedRecord,
  buildWeekDayCompletionSummary,
  enrichWeekCompletionWithPlannedMeals,
};
