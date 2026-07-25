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

function normalizeMealAdherence(existingRecord, incomingMeals, plan) {
  const plannedTypes = getPlannedMealTypes(plan);
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

function applySingleMealToggle(existingRecord, mealType, followed, plan) {
  const plannedTypes = getPlannedMealTypes(plan);
  if (!plannedTypes.includes(mealType)) {
    return existingRecord?.mealAdherence || [];
  }

  const existing = normalizeMealAdherence(existingRecord, existingRecord?.mealAdherence || [], plan);
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

function buildMealCompletionSummary(plan, adherence) {
  const plannedTypes = getPlannedMealTypes(plan);
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
};
