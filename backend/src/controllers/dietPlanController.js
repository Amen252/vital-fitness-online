const DietPlan = require('../models/DietPlan');
const DietAdherence = require('../models/DietAdherence');
const MealLog = require('../models/MealLog');
const Notification = require('../models/Notification');
const FitnessClass = require('../models/FitnessClass');
const User = require('../models/User');
const { buildTodayProgressSnapshot, countPlannedMeals } = require('../utils/dietProgressSnapshot');
const {
  normalizeMealAdherence,
  applySingleMealToggle,
  buildMealCompletionSummary,
  computeAverageAdherence,
  MEAL_LABELS,
} = require('../utils/mealAdherenceUtils');
const { USER_DISPLAY_SELECT, withDisplayName } = require('../utils/userDisplay');
const { hasActiveAssignment } = require('../utils/coachVisibility');

const MEAL_TYPES = ['breakfast', 'lunch', 'dinner', 'snacks'];
const GOALS = ['weight_loss', 'muscle_gain', 'maintenance'];
const PLAN_STATUSES = ['draft', 'active', 'completed', 'archived'];

function planAssigneeName(plan) {
  if (plan?.client) {
    const client = withDisplayName(plan.client);
    return client?.name || 'Client';
  }
  return plan?.fitnessClass?.title || 'Unassigned';
}

async function loadEnrichedDietPlan(planId) {
  const plan = await DietPlan.findById(planId)
    .populate('coach', USER_DISPLAY_SELECT)
    .populate('client', USER_DISPLAY_SELECT)
    .populate('fitnessClass', 'title enrolledStudents')
    .lean();
  return enrichDietPlan(plan);
}

function normalizeStatus(status) {
  const value = String(status || 'active').toLowerCase();
  if (value === 'archived') return 'completed';
  return PLAN_STATUSES.includes(value) ? value : 'active';
}

function displayStatus(status) {
  const normalized = normalizeStatus(status);
  return normalized === 'archived' ? 'completed' : normalized;
}

async function completeActivePlansForAssignee(coachId, { clientId, fitnessClassId }, excludeId) {
  const query = { coach: coachId, status: 'active' };
  if (clientId) query.client = clientId;
  if (fitnessClassId) query.fitnessClass = fitnessClassId;
  if (excludeId) query._id = { $ne: excludeId };
  await DietPlan.updateMany(query, { $set: { status: 'completed' } });
}

/**
 * When activating a plan, move other plans that apply to affected user(s)
 * into history (status: completed).
 * - Individual: complete previous individual plans for that client.
 * - Group: complete previous group plans for that class, and individual
 *   active plans for enrolled members so the group plan becomes visible.
 */
async function supersedePlansForActivation(coachId, plan, excludeId) {
  if (plan.client) {
    await completeActivePlansForAssignee(coachId, { clientId: plan.client }, excludeId);
    return;
  }

  if (plan.fitnessClass) {
    await completeActivePlansForAssignee(coachId, { fitnessClassId: plan.fitnessClass }, excludeId);

    const fitnessClass = await FitnessClass.findById(plan.fitnessClass).select('enrolledStudents').lean();
    const studentIds = (fitnessClass?.enrolledStudents || []).map((id) => id);
    if (studentIds.length) {
      await DietPlan.updateMany(
        {
          coach: coachId,
          status: 'active',
          client: { $in: studentIds },
          ...(excludeId ? { _id: { $ne: excludeId } } : {}),
        },
        { $set: { status: 'completed' } },
      );
    }
  }
}

async function notifyPlanAssigned(plan, { isUpdate = false, isResend = false } = {}) {
  const resolvedGoal = (plan.goal || 'maintenance').replace('_', ' ');
  const action = isResend ? 'shared' : (isUpdate ? 'updated' : 'assigned');
  const messageSuffix = `(${resolvedGoal} · ${plan.dailyCalories} kcal/day).`;

  if (plan.fitnessClass) {
    const fitnessClass = await FitnessClass.findById(plan.fitnessClass).populate('enrolledStudents', USER_DISPLAY_SELECT);
    if (!fitnessClass) return;
    const studentIds = (fitnessClass.enrolledStudents || []).map((s) => s._id || s);
    await notifyUsers(
      studentIds,
      `Your coach ${action} a diet plan for ${fitnessClass.title} ${messageSuffix}`,
      isUpdate || isResend ? 'update' : 'diet',
    );
    await Notification.create({
      user: plan.coach,
      message: `Group diet plan ${action} for ${fitnessClass.title}`,
      type: 'update',
    });
    return;
  }

  if (plan.client) {
    const client = await User.findById(plan.client).select(USER_DISPLAY_SELECT).lean();
    const clientName = withDisplayName(client)?.name || 'your client';
    await notifyUsers(
      [plan.client],
      `Your coach ${action} your diet plan ${messageSuffix}`,
      isUpdate || isResend ? 'update' : 'diet',
    );
    await Notification.create({
      user: plan.coach,
      message: `Diet plan ${action} for ${clientName}`,
      type: 'update',
    });
  }
}

function normalizeMealsArray(meals) {
  if (!meals) return [];

  if (Array.isArray(meals)) {
    return meals.map((meal) => ({
      type: MEAL_TYPES.includes(meal.type) ? meal.type : _inferMealType(meal.name),
      name: meal.name || '',
      description: meal.description || '',
      calories: Number(meal.calories) || 0,
      protein: Number(meal.protein) || 0,
      carbs: Number(meal.carbs) || 0,
      fats: Number(meal.fats) || 0,
      reminderTime: meal.reminderTime || '',
    }));
  }

  if (typeof meals === 'object') {
    return MEAL_TYPES
      .filter((type) => meals[type])
      .map((type) => {
        const val = meals[type];
        if (typeof val === 'string') {
          return { type, name: _capitalize(type), description: val, calories: 0, protein: 0, carbs: 0, fats: 0, reminderTime: '' };
        }
        return {
          type,
          name: val.name || _capitalize(type),
          description: val.description || '',
          calories: Number(val.calories) || 0,
          protein: Number(val.protein) || 0,
          carbs: Number(val.carbs) || 0,
          fats: Number(val.fats) || 0,
          reminderTime: val.reminderTime || '',
        };
      });
  }

  return [];
}

function normalizeDietDays(days) {
  const byDay = new Map();
  if (Array.isArray(days)) {
    for (const day of days) {
      const dow = Number(day.dayOfWeek);
      if (!Number.isFinite(dow) || dow < 0 || dow > 6) continue;
      byDay.set(dow, {
        dayOfWeek: dow,
        meals: normalizeMealsArray(day.meals),
        notes: day.notes || '',
      });
    }
  }
  return Array.from({ length: 7 }, (_, i) => byDay.get(i) || {
    dayOfWeek: i,
    meals: [],
    notes: '',
  });
}

function resolvePlanStructure({ planType, meals, days, targetDayOfWeek }) {
  const type = planType === 'weekly' ? 'weekly' : 'single_day';
  if (type === 'weekly') {
    const normalizedDays = normalizeDietDays(days);
    const hasAnyMeal = normalizedDays.some((d) => d.meals.some((m) => {
      const name = String(m.name || '').trim();
      const description = String(m.description || '').trim();
      return name || description;
    }));
    if (!hasAnyMeal) {
      return { error: 'Add meals for at least one day of the weekly plan' };
    }
    const fallback = normalizedDays.find((d) => d.meals.length)?.meals || [];
    return {
      planType: 'weekly',
      days: normalizedDays,
      meals: fallback,
      targetDayOfWeek: null,
    };
  }
  const normalizedMeals = normalizeMealsArray(meals);
  let day = targetDayOfWeek;
  if (day != null && day !== '') {
    day = Number(day);
    if (!Number.isFinite(day) || day < 0 || day > 6) {
      return { error: 'Select a valid day for the single-day plan' };
    }
  } else {
    day = null;
  }
  if (day == null) {
    return { error: 'Check one day for the single-day diet plan' };
  }
  if (!normalizedMeals.some((m) => {
    const name = String(m.name || '').trim();
    const description = String(m.description || '').trim();
    return name || description;
  })) {
    return { error: 'Add at least one meal for the selected day' };
  }
  return {
    planType: 'single_day',
    days: [],
    meals: normalizedMeals,
    targetDayOfWeek: day,
  };
}

function enrichDietPlan(plan, date = new Date()) {
  if (!plan) return plan;
  const { getMealsForDate, mondayBasedDayOfWeek, DAY_NAMES } = require('../utils/mealAdherenceUtils');
  const obj = plan.toObject ? plan.toObject() : { ...plan };
  if (obj.client) obj.client = withDisplayName(obj.client);
  if (obj.coach) obj.coach = withDisplayName(obj.coach);
  const todaysMeals = getMealsForDate(obj, date);
  const dow = mondayBasedDayOfWeek(date);
  const target = obj.targetDayOfWeek != null ? Number(obj.targetDayOfWeek) : null;
  return {
    ...obj,
    planType: obj.planType || 'single_day',
    days: Array.isArray(obj.days) ? obj.days : [],
    meals: Array.isArray(obj.meals) ? obj.meals : [],
    targetDayOfWeek: Number.isFinite(target) ? target : null,
    targetDayName: Number.isFinite(target) ? DAY_NAMES[target] : null,
    todaysMeals,
    todayDayOfWeek: dow,
    todayDayName: DAY_NAMES[dow],
    assigneeType: obj.client ? 'user' : 'group',
    assigneeName: planAssigneeName(obj),
  };
}

function mealsForReminders(plan) {
  const { getMealsForDate } = require('../utils/mealAdherenceUtils');
  return getMealsForDate(plan);
}

function _inferMealType(name) {
  const label = String(name || '').toLowerCase();
  if (label.includes('break')) return 'breakfast';
  if (label.includes('lunch')) return 'lunch';
  if (label.includes('dinner')) return 'dinner';
  return 'snacks';
}

function _capitalize(str) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

function startOfDay(date = new Date()) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

async function notifyUsers(userIds, message, type = 'diet') {
  if (!userIds.length) return;
  await Notification.insertMany(
    userIds.map((userId) => ({ user: userId, message, type })),
  );
}

async function resolveUserDietPlan(clientId) {
  const individual = await DietPlan.findOne({
    client: clientId,
    status: 'active',
  })
    .populate('coach', USER_DISPLAY_SELECT)
    .populate('client', USER_DISPLAY_SELECT)
    .populate('fitnessClass', 'title')
    .lean();

  if (individual) return individual;

  const classIds = await FitnessClass.find({ enrolledStudents: clientId }).distinct('_id');
  if (!classIds.length) return null;

  return DietPlan.findOne({
    fitnessClass: { $in: classIds },
    status: 'active',
  })
    .populate('coach', USER_DISPLAY_SELECT)
    .populate('fitnessClass', 'title')
    .sort({ updatedAt: -1 })
    .lean();
}

/** Past (completed) diet plans for this user — personal or via a group. */
async function getUserDietPlanHistory(req, res) {
  try {
    const userId = req.user._id;
    const classIds = await FitnessClass.find({ enrolledStudents: userId }).distinct('_id');

    const plans = await DietPlan.find({
      status: { $in: ['completed', 'archived'] },
      $or: [
        { client: userId },
        ...(classIds.length ? [{ fitnessClass: { $in: classIds } }] : []),
      ],
    })
      .populate('coach', USER_DISPLAY_SELECT)
      .populate('client', USER_DISPLAY_SELECT)
      .populate('fitnessClass', 'title')
      .sort({ updatedAt: -1 })
      .limit(50)
      .lean();

    return res.json({
      plans: plans.map((plan) => ({
        ...plan,
        status: displayStatus(plan.status),
        assigneeType: plan.client ? 'user' : 'group',
        assigneeName: planAssigneeName(plan),
      })),
    });
  } catch (error) {
    console.error('getUserDietPlanHistory:', error.message);
    return res.status(500).json({ message: 'Error fetching diet plan history' });
  }
}

async function verifyCoachClient(coachId, clientId) {
  return hasActiveAssignment(coachId, clientId);
}

// --- User endpoints ---

async function getUserAssignedDietPlan(req, res) {
  try {
    const clientId = req.user.role === 'coach' ? req.query.clientId : req.user._id;
    if (!clientId) {
      return res.status(400).json({ message: 'clientId required for coach' });
    }

    if (req.user.role === 'coach') {
      const allowed = await verifyCoachClient(req.user._id, clientId);
      if (!allowed) return res.status(403).json({ message: 'Client not assigned to you' });
    }

    const plan = await resolveUserDietPlan(clientId);

    if (!plan) {
      return res.status(404).json({ message: 'No active diet plan found' });
    }

    const today = startOfDay();
    const todaySnapshot = await buildTodayProgressSnapshot(clientId, plan);

    return res.json({
      plan: enrichDietPlan(plan),
      today: {
        ...todaySnapshot,
        adherence: await DietAdherence.findOne({ user: clientId, date: today }).lean(),
        weeklyAveragePercent: await computeAverageAdherence(DietAdherence, clientId, 7),
      },
    });
  } catch (error) {
    console.error('getUserAssignedDietPlan:', error.message);
    return res.status(500).json({ message: 'Error fetching diet plan' });
  }
}

async function getUserDietProgress(req, res) {
  try {
    const days = Math.min(parseInt(req.query.days, 10) || 14, 90);
    const since = new Date();
    since.setDate(since.getDate() - days);

    const [plan, adherence, mealLogs] = await Promise.all([
      resolveUserDietPlan(req.user._id),
      DietAdherence.find({ user: req.user._id, date: { $gte: since } }).sort({ date: -1 }).lean(),
      MealLog.find({ user: req.user._id, date: { $gte: since } }).sort({ date: -1 }).lean(),
    ]);

    const avgAdherence = adherence.length
      ? Math.round(adherence.reduce((s, a) => s + (a.adherencePercent || 0), 0) / adherence.length)
      : 0;

    const todaySnapshot = await buildTodayProgressSnapshot(req.user._id, plan);
    const weeklyAveragePercent = await computeAverageAdherence(DietAdherence, req.user._id, 7);

    const weightHistory = adherence
      .filter((a) => a.weightKg != null)
      .map((a) => ({ date: a.date, weightKg: a.weightKg }));

    return res.json({
      plan,
      avgAdherence,
      weeklyAveragePercent,
      today: todaySnapshot,
      adherenceHistory: adherence,
      mealLogs,
      weightHistory,
    });
  } catch (error) {
    console.error('getUserDietProgress:', error.message);
    return res.status(500).json({ message: 'Error fetching diet progress' });
  }
}

async function logUserAdherence(req, res) {
  try {
    const {
      followedPlan,
      weightKg,
      mealAdherence,
      mealType,
      followed,
      notes,
      caloriesConsumed,
    } = req.body;

    const plan = await resolveUserDietPlan(req.user._id);
    const today = startOfDay();

    let resolvedCalories = caloriesConsumed;
    if (resolvedCalories == null) {
      const todayLogs = await MealLog.find({ user: req.user._id, date: { $gte: today } }).lean();
      resolvedCalories = todayLogs.reduce((sum, l) => sum + (l.calories || 0), 0);
    }

    const existing = await DietAdherence.findOne({ user: req.user._id, date: today }).lean();

    let normalizedMeals;
    if (mealType && MEAL_LABELS[mealType]) {
      normalizedMeals = applySingleMealToggle(existing, mealType, followed, plan);
    } else {
      normalizedMeals = normalizeMealAdherence(existing, mealAdherence, plan);
    }

    const summary = buildMealCompletionSummary(plan, { mealAdherence: normalizedMeals });
    const adherencePercent = summary.dailyProgressPercent;
    const isFullyCompleted = summary.allCompleted;

    const record = await DietAdherence.findOneAndUpdate(
      { user: req.user._id, date: today },
      {
        $set: {
          coach: plan?.coach,
          dietPlan: plan?._id,
          weightKg,
          caloriesConsumed: resolvedCalories || 0,
          targetCalories: plan?.dailyCalories || 0,
          followedPlan: isFullyCompleted,
          completedAt: isFullyCompleted ? (existing?.completedAt || new Date()) : null,
          adherencePercent,
          coachMarked: false,
          mealAdherence: normalizedMeals,
          notes: notes || existing?.notes || '',
        },
        $setOnInsert: {
          user: req.user._id,
          date: today,
        },
      },
      { upsert: true, new: true, runValidators: true },
    );

    if (plan?.coach && mealType && followed) {
      const prevMeal = (existing?.mealAdherence || []).find((m) => m.type === mealType);
      if (!(prevMeal && prevMeal.followed)) {
        await Notification.create({
          user: plan.coach,
          message: `${req.user.name || 'A client'} completed ${MEAL_LABELS[mealType] || mealType} on their diet plan.`,
          type: 'diet',
        });
      }
    }

    if (plan?.coach && isFullyCompleted && !(existing && existing.followedPlan)) {
      await Notification.create({
        user: plan.coach,
        message: `${req.user.name || 'A client'} completed all meals on their diet plan today.`,
        type: 'diet',
      });
    }

    return res.json({
      ...record.toObject(),
      mealSummary: summary,
      weeklyAveragePercent: await computeAverageAdherence(DietAdherence, req.user._id, 7),
    });
  } catch (error) {
    console.error('logUserAdherence:', error.message);
    return res.status(500).json({ message: 'Error logging adherence' });
  }
}

// --- Coach endpoints ---

async function getCoachDietPlans(req, res) {
  try {
    const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
    const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 10, 1), 50);
    const skip = (page - 1) * limit;
    const search = String(req.query.search || '').trim().toLowerCase();
    const statusFilter = String(req.query.status || 'all').toLowerCase();
    const assigneeType = String(req.query.assigneeType || 'all').toLowerCase();
    const sortOrder = String(req.query.sort || 'newest').toLowerCase() === 'oldest' ? 1 : -1;

    const query = { coach: req.user._id };
    if (statusFilter !== 'all') {
      if (statusFilter === 'completed') {
        query.status = { $in: ['completed', 'archived'] };
      } else {
        query.status = statusFilter;
      }
    } else {
      query.status = { $ne: 'archived' };
    }

    if (assigneeType === 'user') {
      query.client = { $ne: null };
    } else if (assigneeType === 'group') {
      query.fitnessClass = { $ne: null };
    }

    const fetchLimit = search ? Math.min(limit * 20, 200) : limit;
    const fetchSkip = search ? 0 : skip;

    const plans = await DietPlan.find(query)
      .populate('client', USER_DISPLAY_SELECT)
      .populate('fitnessClass', 'title enrolledStudents')
      .sort({ createdAt: sortOrder })
      .skip(fetchSkip)
      .limit(fetchLimit)
      .lean();

    let enriched = plans.map((plan) => ({
      ...plan,
      status: displayStatus(plan.status),
      assigneeType: plan.client ? 'user' : 'group',
      assigneeName: planAssigneeName(plan),
      client: plan.client ? withDisplayName(plan.client) : plan.client,
    }));

    if (search) {
      enriched = enriched.filter((plan) => {
        const clientName = (plan.assigneeName || '').toLowerCase();
        const className = plan.fitnessClass?.title?.toLowerCase() || '';
        const title = plan.title?.toLowerCase() || '';
        return clientName.includes(search) || className.includes(search) || title.includes(search);
      });
    }

    const total = search ? enriched.length : await DietPlan.countDocuments(query);
    const paged = search ? enriched.slice(skip, skip + limit) : enriched;

    return res.json({
      plans: paged,
      total,
      page,
      limit,
      totalPages: Math.max(Math.ceil(total / limit), 1),
    });
  } catch (error) {
    console.error('getCoachDietPlans:', error.message);
    return res.status(500).json({ message: 'Error fetching diet plans' });
  }
}

async function getDietPlanById(req, res) {
  try {
    const plan = await DietPlan.findOne({ _id: req.params.id, coach: req.user._id })
      .populate('client', USER_DISPLAY_SELECT)
      .populate('fitnessClass', 'title enrolledStudents')
      .lean();
    if (!plan) return res.status(404).json({ message: 'Diet plan not found' });
    const enriched = enrichDietPlan(plan);
    return res.json({
      ...enriched,
      status: displayStatus(plan.status),
      assigneeType: plan.client ? 'user' : 'group',
      assigneeName: planAssigneeName(plan),
    });
  } catch (error) {
    console.error('getDietPlanById:', error.message);
    return res.status(500).json({ message: 'Error fetching diet plan' });
  }
}

async function getClientDietPlan(req, res) {
  try {
    const { clientId } = req.params;
    const allowed = await verifyCoachClient(req.user._id, clientId);
    if (!allowed) return res.status(403).json({ message: 'Client not assigned to you' });

    const plan = await DietPlan.findOne({
      coach: req.user._id,
      client: clientId,
      status: 'active',
    })
      .populate('client', USER_DISPLAY_SELECT)
      .lean();

    return res.json(plan ? enrichDietPlan(plan) : null);
  } catch (error) {
    console.error('getClientDietPlan:', error.message);
    return res.status(500).json({ message: 'Error fetching client diet plan' });
  }
}

async function getGroupDietPlan(req, res) {
  try {
    const fitnessClass = await FitnessClass.findOne({
      _id: req.params.classId,
      coach: req.user._id,
    });
    if (!fitnessClass) return res.status(404).json({ message: 'Class not found' });

    const plan = await DietPlan.findOne({
      coach: req.user._id,
      fitnessClass: req.params.classId,
      status: 'active',
    })
      .populate('fitnessClass', 'title enrolledStudents')
      .lean();

    return res.json(plan ? enrichDietPlan(plan) : null);
  } catch (error) {
    console.error('getGroupDietPlan:', error.message);
    return res.status(500).json({ message: 'Error fetching group diet plan' });
  }
}

async function getGroupDietProgress(req, res) {
  try {
    const fitnessClass = await FitnessClass.findOne({
      _id: req.params.classId,
      coach: req.user._id,
    }).populate('enrolledStudents', USER_DISPLAY_SELECT);

    if (!fitnessClass) return res.status(403).json({ message: 'Class not found' });

    const days = Math.min(parseInt(req.query.days, 10) || 14, 90);
    const since = new Date();
    since.setDate(since.getDate() - days);

    const studentIds = (fitnessClass.enrolledStudents || []).map((s) => s._id || s);

    const [plan, adherence] = await Promise.all([
      DietPlan.findOne({ coach: req.user._id, fitnessClass: req.params.classId, status: 'active' }).lean(),
      DietAdherence.find({ user: { $in: studentIds }, date: { $gte: since } }).sort({ date: -1 }).lean(),
    ]);

    const avgAdherence = adherence.length
      ? Math.round(adherence.reduce((s, a) => s + (a.adherencePercent || 0), 0) / adherence.length)
      : 0;

    const memberSnapshots = studentIds.length
      ? await Promise.all(studentIds.map((id) => buildTodayProgressSnapshot(id, plan)))
      : [];

    const today = memberSnapshots.length
      ? {
          caloriesConsumed: Math.round(memberSnapshots.reduce((s, m) => s + m.caloriesConsumed, 0) / memberSnapshots.length),
          targetCalories: plan?.dailyCalories || 0,
          waterMl: Math.round(memberSnapshots.reduce((s, m) => s + m.waterMl, 0) / memberSnapshots.length),
          targetWaterMl: memberSnapshots[0]?.targetWaterMl || 2000,
          mealsCompleted: Math.round(memberSnapshots.reduce((s, m) => s + m.mealsCompleted, 0) / memberSnapshots.length),
          mealsPlanned: plan ? countPlannedMeals(plan) : 0,
          workoutsCompleted: Math.round(memberSnapshots.reduce((s, m) => s + m.workoutsCompleted, 0) / memberSnapshots.length),
          workoutsPlanned: Math.max(...memberSnapshots.map((m) => m.workoutsPlanned), 0),
          dailyGoalPercent: memberSnapshots.length
            ? Math.round(memberSnapshots.reduce((s, m) => s + m.dailyGoalPercent, 0) / memberSnapshots.length)
            : 0,
          adherencePercent: avgAdherence,
          followedPlan: memberSnapshots.some((m) => m.followedPlan),
          hasActivity: memberSnapshots.some((m) => m.hasActivity),
        }
      : {
          caloriesConsumed: 0,
          targetCalories: plan?.dailyCalories || 0,
          waterMl: 0,
          targetWaterMl: 2000,
          mealsCompleted: 0,
          mealsPlanned: plan ? countPlannedMeals(plan) : 0,
          workoutsCompleted: 0,
          workoutsPlanned: 0,
          dailyGoalPercent: 0,
          adherencePercent: 0,
          followedPlan: false,
          hasActivity: false,
        };

    const perMember = studentIds.map((id, index) => {
      const member = fitnessClass.enrolledStudents.find((s) => String(s._id) === String(id));
      const memberRecords = adherence.filter((a) => String(a.user) === String(id));
      const latest = memberRecords[0];
      const snapshot = memberSnapshots[index] || {};
      return {
        userId: id,
        name: withDisplayName(member)?.name || 'Member',
        latestAdherence: latest,
        mealAdherence: latest?.mealAdherence || snapshot.mealAdherence || [],
        mealsCompleted: snapshot.mealsCompleted || 0,
        mealsPlanned: snapshot.mealsPlanned || (plan ? countPlannedMeals(plan) : 0),
        avgAdherence: memberRecords.length
          ? Math.round(memberRecords.reduce((s, r) => s + (r.adherencePercent || 0), 0) / memberRecords.length)
          : 0,
      };
    });

    const plannedTypes = plan
      ? require('../utils/mealAdherenceUtils').getPlannedMealTypes(plan)
      : [];

    return res.json({
      plan,
      memberCount: studentIds.length,
      avgAdherence,
      today: {
        ...today,
        mealAdherence: [],
        plannedMealTypes: plannedTypes,
      },
      caloriesToday: today.caloriesConsumed,
      adherenceHistory: adherence,
      members: perMember,
      plannedMealTypes: plannedTypes,
    });
  } catch (error) {
    console.error('getGroupDietProgress:', error.message);
    return res.status(500).json({ message: 'Error fetching group progress' });
  }
}

async function createOrUpdateDietPlan(req, res) {
  try {
    const {
      planId,
      clientId,
      fitnessClassId,
      title,
      goal,
      meals,
      days,
      planType,
      targetDayOfWeek,
      dailyCalories,
      notes,
      status,
    } = req.body;

    if (!dailyCalories) {
      return res.status(400).json({ message: 'dailyCalories is required' });
    }
    if (!clientId && !fitnessClassId) {
      return res.status(400).json({ message: 'clientId or fitnessClassId is required' });
    }
    if (clientId && fitnessClassId) {
      return res.status(400).json({ message: 'Provide either clientId or fitnessClassId, not both' });
    }

    const structure = resolvePlanStructure({ planType, meals, days, targetDayOfWeek });
    if (structure.error) {
      return res.status(400).json({ message: structure.error });
    }

    const resolvedGoal = GOALS.includes(goal) ? goal : 'maintenance';
    const resolvedStatus = normalizeStatus(status || 'active');
    const shouldNotify = resolvedStatus === 'active';

    const applyFields = (plan) => {
      plan.title = title || plan.title;
      plan.goal = resolvedGoal;
      plan.planType = structure.planType;
      plan.meals = structure.meals;
      plan.days = structure.days;
      plan.targetDayOfWeek = structure.targetDayOfWeek;
      plan.markModified('days');
      plan.dailyCalories = dailyCalories;
      plan.notes = notes || '';
      plan.status = resolvedStatus;
    };

    if (fitnessClassId) {
      const fitnessClass = await FitnessClass.findOne({
        _id: fitnessClassId,
        coach: req.user._id,
      });
      if (!fitnessClass) {
        return res.status(404).json({ message: 'Class not found' });
      }

      let plan;
      let isUpdate = false;

      if (planId) {
        plan = await DietPlan.findOne({ _id: planId, coach: req.user._id, fitnessClass: fitnessClassId });
        if (!plan) return res.status(404).json({ message: 'Diet plan not found' });
        isUpdate = true;
        applyFields(plan);
        await plan.save();
      } else {
        plan = await DietPlan.create({
          coach: req.user._id,
          fitnessClass: fitnessClassId,
          title: title || `${fitnessClass.title} Diet Plan`,
          goal: resolvedGoal,
          planType: structure.planType,
          meals: structure.meals,
          days: structure.days,
          targetDayOfWeek: structure.targetDayOfWeek,
          dailyCalories,
          notes: notes || '',
          status: resolvedStatus,
        });
      }

      if (shouldNotify) {
        await supersedePlansForActivation(req.user._id, plan, plan._id);
        plan.status = 'active';
        await plan.save();
        await notifyPlanAssigned(plan, { isUpdate });
      }

      return res.status(isUpdate ? 200 : 201).json(await loadEnrichedDietPlan(plan._id));
    }

    const allowed = await verifyCoachClient(req.user._id, clientId);
    if (!allowed) return res.status(403).json({ message: 'Client not assigned to you' });

    let plan;
    let isUpdate = false;

    if (planId) {
      plan = await DietPlan.findOne({ _id: planId, coach: req.user._id, client: clientId });
      if (!plan) return res.status(404).json({ message: 'Diet plan not found' });
      isUpdate = true;
      applyFields(plan);
      await plan.save();
    } else {
      plan = await DietPlan.create({
        coach: req.user._id,
        client: clientId,
        title: title || 'Diet Plan',
        goal: resolvedGoal,
        planType: structure.planType,
        meals: structure.meals,
        days: structure.days,
        targetDayOfWeek: structure.targetDayOfWeek,
        dailyCalories,
        notes: notes || '',
        status: resolvedStatus,
      });
    }

    if (shouldNotify) {
      await supersedePlansForActivation(req.user._id, plan, plan._id);
      plan.status = 'active';
      await plan.save();
      await notifyPlanAssigned(plan, { isUpdate });
    }

    return res.status(isUpdate ? 200 : 201).json(await loadEnrichedDietPlan(plan._id));
  } catch (error) {
    console.error('createOrUpdateDietPlan:', error.message);
    return res.status(500).json({ message: 'Error saving diet plan' });
  }
}

async function updateDietPlanById(req, res) {
  try {
    const plan = await DietPlan.findOne({ _id: req.params.id, coach: req.user._id });
    if (!plan) return res.status(404).json({ message: 'Diet plan not found' });

    const previousStatus = plan.status;
    const { title, goal, meals, days, planType, targetDayOfWeek, dailyCalories, notes, status } = req.body;
    if (title) plan.title = title;
    if (goal && GOALS.includes(goal)) plan.goal = goal;
    if (planType !== undefined || meals !== undefined || days !== undefined || targetDayOfWeek !== undefined) {
      const structure = resolvePlanStructure({
        planType: planType || plan.planType || 'single_day',
        meals: meals !== undefined ? meals : plan.meals,
        days: days !== undefined ? days : plan.days,
        targetDayOfWeek: targetDayOfWeek !== undefined ? targetDayOfWeek : plan.targetDayOfWeek,
      });
      if (structure.error) {
        return res.status(400).json({ message: structure.error });
      }
      plan.planType = structure.planType;
      plan.meals = structure.meals;
      plan.days = structure.days;
      plan.targetDayOfWeek = structure.targetDayOfWeek;
      plan.markModified('days');
    }
    if (dailyCalories) plan.dailyCalories = dailyCalories;
    if (notes !== undefined) plan.notes = notes;
    if (status) plan.status = normalizeStatus(status);

    const becomingActive = plan.status === 'active' && previousStatus !== 'active';
    if (becomingActive) {
      await supersedePlansForActivation(req.user._id, plan, plan._id);
      plan.status = 'active';
    }

    await plan.save();

    if (plan.status === 'active') {
      await notifyPlanAssigned(plan, { isUpdate: !becomingActive });
    }

    return res.json(plan);
  } catch (error) {
    console.error('updateDietPlanById:', error.message);
    return res.status(500).json({ message: 'Error updating diet plan' });
  }
}

async function sendDietPlanAgain(req, res) {
  try {
    const plan = await DietPlan.findOne({ _id: req.params.id, coach: req.user._id });
    if (!plan) return res.status(404).json({ message: 'Diet plan not found' });

    if (plan.status === 'draft') {
      await supersedePlansForActivation(req.user._id, plan, plan._id);
      plan.status = 'active';
      await plan.save();
      await notifyPlanAssigned(plan, { isResend: false });
    } else {
      await notifyPlanAssigned(plan, { isResend: true });
    }

    return res.json({ message: 'Diet plan sent successfully', plan });
  } catch (error) {
    console.error('sendDietPlanAgain:', error.message);
    return res.status(500).json({ message: 'Error sending diet plan' });
  }
}

async function getDietPlanCompletions(req, res) {
  try {
    const coachId = req.user._id;
    const filter = String(req.query.status || 'all').toLowerCase();
    const today = startOfDay();

    const [individualPlans, groupPlans] = await Promise.all([
      DietPlan.find({
        coach: coachId,
        status: 'active',
        client: { $ne: null },
      })
        .populate('client', USER_DISPLAY_SELECT)
        .lean(),
      DietPlan.find({
        coach: coachId,
        status: 'active',
        fitnessClass: { $ne: null },
      })
        .populate({
          path: 'fitnessClass',
          select: 'title enrolledStudents',
          populate: { path: 'enrolledStudents', select: USER_DISPLAY_SELECT },
        })
        .lean(),
    ]);

    const entries = [];

    for (const plan of individualPlans) {
      if (!plan.client) continue;
      const clientId = plan.client._id || plan.client;
      const adherence = await DietAdherence.findOne({ user: clientId, date: today }).lean();
      const summary = buildMealCompletionSummary(plan, adherence);
      const weeklyAveragePercent = await computeAverageAdherence(DietAdherence, clientId, 7);

      entries.push({
        userId: clientId,
        userName: withDisplayName(plan.client)?.name || 'Client',
        planId: plan._id,
        planName: plan.title || 'Diet Plan',
        assigneeType: 'user',
        completed: summary.allCompleted,
        progressPercent: summary.dailyProgressPercent,
        completedMeals: summary.completedMeals,
        missedMeals: summary.missedMeals,
        mealsPlanned: summary.mealsPlanned,
        meals: summary.meals,
        weeklyAveragePercent,
        completionDate: summary.allCompleted ? (adherence?.completedAt || null) : null,
        status: summary.allCompleted ? 'completed' : 'not_completed',
      });
    }

    for (const plan of groupPlans) {
      const classDoc = plan.fitnessClass;
      const students = classDoc?.enrolledStudents || [];
      for (const student of students) {
        const studentId = student._id || student;
        const studentName = withDisplayName(student)?.name || 'Member';
        const adherence = await DietAdherence.findOne({ user: studentId, date: today }).lean();
        const summary = buildMealCompletionSummary(plan, adherence);
        const weeklyAveragePercent = await computeAverageAdherence(DietAdherence, studentId, 7);

        entries.push({
          userId: studentId,
          userName: studentName,
          planId: plan._id,
          planName: plan.title || `${classDoc?.title || 'Group'} Diet Plan`,
          assigneeType: 'group',
          groupName: classDoc?.title || 'Group',
          completed: summary.allCompleted,
          progressPercent: summary.dailyProgressPercent,
          completedMeals: summary.completedMeals,
          missedMeals: summary.missedMeals,
          mealsPlanned: summary.mealsPlanned,
          meals: summary.meals,
          weeklyAveragePercent,
          completionDate: summary.allCompleted ? (adherence?.completedAt || null) : null,
          status: summary.allCompleted ? 'completed' : 'not_completed',
        });
      }
    }

    entries.sort((a, b) => a.userName.localeCompare(b.userName));

    let users = entries;
    if (filter === 'completed') {
      users = entries.filter((e) => e.completed);
    } else if (filter === 'not_completed') {
      users = entries.filter((e) => !e.completed && e.mealsPlanned > 0);
    }

    return res.json({
      users,
      total: users.length,
      completedCount: entries.filter((e) => e.completed).length,
      notCompletedCount: entries.filter((e) => !e.completed).length,
    });
  } catch (error) {
    console.error('getDietPlanCompletions:', error.message);
    return res.status(500).json({ message: 'Error fetching diet plan completions' });
  }
}

async function archiveDietPlan(req, res) {
  try {
    const plan = await DietPlan.findOneAndUpdate(
      { _id: req.params.id, coach: req.user._id },
      { $set: { status: 'completed' } },
      { new: true, runValidators: true },
    );
    if (!plan) return res.status(404).json({ message: 'Diet plan not found' });
    return res.json(plan);
  } catch (error) {
    console.error('archiveDietPlan:', error.message);
    return res.status(500).json({ message: 'Error deleting diet plan' });
  }
}

async function getClientDietProgress(req, res) {
  try {
    const { clientId } = req.params;
    const allowed = await verifyCoachClient(req.user._id, clientId);
    if (!allowed) return res.status(403).json({ message: 'Client not assigned to you' });

    const days = Math.min(parseInt(req.query.days, 10) || 14, 90);
    const since = new Date();
    since.setDate(since.getDate() - days);

    let plan = null;
    if (req.query.planId) {
      plan = await DietPlan.findOne({ _id: req.query.planId, coach: req.user._id }).lean();
    }
    if (!plan) {
      plan = await DietPlan.findOne({ coach: req.user._id, client: clientId, status: 'active' }).lean();
    }
    if (!plan) {
      // Fall back to an active group plan for a class this coach owns and the client is in.
      const classIds = await FitnessClass.find({
        coach: req.user._id,
        enrolledStudents: clientId,
      }).distinct('_id');
      if (classIds.length) {
        plan = await DietPlan.findOne({
          coach: req.user._id,
          fitnessClass: { $in: classIds },
          status: 'active',
        })
          .sort({ updatedAt: -1 })
          .lean();
      }
    }

    const [adherence, mealLogs] = await Promise.all([
      DietAdherence.find({ user: clientId, date: { $gte: since } }).sort({ date: -1 }).lean(),
      MealLog.find({ user: clientId, date: { $gte: since } }).sort({ date: -1 }).lean(),
    ]);

    const avgAdherence = adherence.length
      ? Math.round(adherence.reduce((s, a) => s + (a.adherencePercent || 0), 0) / adherence.length)
      : 0;

    const todaySnapshot = await buildTodayProgressSnapshot(clientId, plan);
    const plannedMealTypes = plan
      ? require('../utils/mealAdherenceUtils').getPlannedMealTypes(plan)
      : [];

    return res.json({
      plan,
      avgAdherence,
      today: {
        ...todaySnapshot,
        plannedMealTypes,
      },
      caloriesToday: todaySnapshot.caloriesConsumed,
      adherenceHistory: adherence,
      mealLogs,
      weightHistory: adherence.filter((a) => a.weightKg != null).map((a) => ({
        date: a.date,
        weightKg: a.weightKg,
      })),
      plannedMealTypes,
    });
  } catch (error) {
    console.error('getClientDietProgress:', error.message);
    return res.status(500).json({ message: 'Error fetching client progress' });
  }
}

async function markClientAdherence(req, res) {
  try {
    const { clientId } = req.params;
    const { date, followedPlan, adherencePercent, notes, weightKg } = req.body;

    const allowed = await verifyCoachClient(req.user._id, clientId);
    if (!allowed) return res.status(403).json({ message: 'Client not assigned to you' });

    const plan = await DietPlan.findOne({ coach: req.user._id, client: clientId, status: 'active' })
      || await (async () => {
        const classIds = await FitnessClass.find({
          coach: req.user._id,
          enrolledStudents: clientId,
        }).distinct('_id');
        if (!classIds.length) return null;
        return DietPlan.findOne({
          coach: req.user._id,
          fitnessClass: { $in: classIds },
          status: 'active',
        }).sort({ updatedAt: -1 });
      })();
    const recordDate = date ? startOfDay(new Date(date)) : startOfDay();
    const { getPlannedMealTypes } = require('../utils/mealAdherenceUtils');
    const plannedTypes = plan ? getPlannedMealTypes(plan) : [];
    const mealAdherence = followedPlan
      ? plannedTypes.map((type) => ({
          type,
          followed: true,
          completedAt: new Date(),
          notes: '',
        }))
      : plannedTypes.map((type) => ({
          type,
          followed: false,
          completedAt: null,
          notes: '',
        }));

    const record = await DietAdherence.findOneAndUpdate(
      { user: clientId, date: recordDate },
      {
        $set: {
          coach: req.user._id,
          dietPlan: plan?._id,
          followedPlan: !!followedPlan,
          adherencePercent: adherencePercent ?? (followedPlan ? 100 : 0),
          coachMarked: true,
          weightKg,
          targetCalories: plan?.dailyCalories || 0,
          notes: notes || '',
          mealAdherence,
        },
        $setOnInsert: {
          user: clientId,
          date: recordDate,
        },
      },
      { upsert: true, new: true, runValidators: true },
    );

    return res.json(record);
  } catch (error) {
    console.error('markClientAdherence:', error.message);
    return res.status(500).json({ message: 'Error marking adherence' });
  }
}

async function sendGroupMealReminders(req, res) {
  try {
    const fitnessClass = await FitnessClass.findOne({
      _id: req.params.classId,
      coach: req.user._id,
    });
    if (!fitnessClass) return res.status(403).json({ message: 'Class not found' });

    const plan = await DietPlan.findOne({
      coach: req.user._id,
      fitnessClass: req.params.classId,
      status: 'active',
    });
    if (!plan) return res.status(404).json({ message: 'No active diet plan for this group' });

    const studentIds = (fitnessClass.enrolledStudents || []).map((id) => id);
    const dayMeals = mealsForReminders(plan);
    const mealsWithReminders = dayMeals.filter((m) => m.reminderTime);
    const mealsToSend = mealsWithReminders.length ? mealsWithReminders : dayMeals;

    for (const studentId of studentIds) {
      for (const meal of mealsToSend) {
        const msg = meal.reminderTime
          ? `Meal reminder at ${meal.reminderTime}: ${meal.name || meal.type} — ${meal.calories || 0} kcal.`
          : `Meal reminder: Time for ${meal.name || meal.type} (${meal.calories || 0} kcal).`;
        await Notification.create({ user: studentId, message: msg, type: 'reminder' });
      }
    }

    return res.json({
      sent: studentIds.length * mealsToSend.length,
      message: 'Meal reminders sent to group',
    });
  } catch (error) {
    console.error('sendGroupMealReminders:', error.message);
    return res.status(500).json({ message: 'Error sending reminders' });
  }
}

async function sendMealReminders(req, res) {
  try {
    const { clientId } = req.params;
    const allowed = await verifyCoachClient(req.user._id, clientId);
    if (!allowed) return res.status(403).json({ message: 'Client not assigned to you' });

    const plan = await DietPlan.findOne({ coach: req.user._id, client: clientId, status: 'active' });
    if (!plan) return res.status(404).json({ message: 'No active diet plan for client' });

    const dayMeals = mealsForReminders(plan);
    const mealsWithReminders = dayMeals.filter((m) => m.reminderTime);
    if (mealsWithReminders.length === 0) {
      for (const meal of dayMeals) {
        await Notification.create({
          user: clientId,
          message: `Meal reminder: Time for ${meal.name || meal.type} (${meal.calories || 0} kcal).`,
          type: 'reminder',
        });
      }
      return res.json({ sent: dayMeals.length, message: 'Meal reminders sent' });
    }

    for (const meal of mealsWithReminders) {
      await Notification.create({
        user: clientId,
        message: `Meal reminder at ${meal.reminderTime}: ${meal.name || meal.type} — ${meal.calories || 0} kcal.`,
        type: 'reminder',
      });
    }

    return res.json({ sent: mealsWithReminders.length, message: 'Meal reminders sent' });
  } catch (error) {
    console.error('sendMealReminders:', error.message);
    return res.status(500).json({ message: 'Error sending reminders' });
  }
}

module.exports = {
  getUserAssignedDietPlan,
  getUserDietPlanHistory,
  getUserDietProgress,
  logUserAdherence,
  getCoachDietPlans,
  getDietPlanCompletions,
  getDietPlanById,
  getClientDietPlan,
  getGroupDietPlan,
  getGroupDietProgress,
  createOrUpdateDietPlan,
  updateDietPlanById,
  archiveDietPlan,
  sendDietPlanAgain,
  getClientDietProgress,
  markClientAdherence,
  sendMealReminders,
  sendGroupMealReminders,
  normalizeMealsArray,
};
