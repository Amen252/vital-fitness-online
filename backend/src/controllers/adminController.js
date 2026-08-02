const User = require('../models/User');
const Profile = require('../models/Profile');
const CoachAssignment = require('../models/CoachAssignment');
const CoachClientAssignment = require('../models/CoachClientAssignment');
const AuditLog = require('../models/AuditLog');
const CoachRequest = require('../models/CoachRequest');
const ActivityLog = require('../models/ActivityLog');
const MealLog = require('../models/MealLog');
const WaterLog = require('../models/WaterLog');
const FitnessClass = require('../models/FitnessClass');
const Notification = require('../models/Notification');
const CoachApplication = require('../models/CoachApplication');
const Appointment = require('../models/Appointment');
const DietPlan = require('../models/DietPlan');
const DietAdherence = require('../models/DietAdherence');
const ExercisePlan = require('../models/ExercisePlan');
const WorkoutCompletion = require('../models/WorkoutCompletion');
const WorkoutTemplate = require('../models/WorkoutTemplate');
const WeeklyWorkoutPlan = require('../models/WeeklyWorkoutPlan');
const WorkoutSchedule = require('../models/WorkoutSchedule');
const ScheduleCompletion = require('../models/ScheduleCompletion');
const Schedule = require('../models/Schedule');
const Session = require('../models/Session');
const Message = require('../models/Message');
const Review = require('../models/Review');
const { validationResult } = require('express-validator');
const { purgeUserAccount } = require('../utils/purgeUserAccount');
const { buildMemberUserFilter } = require('../utils/memberUserQuery');
const { enrichCoachUser } = require('../utils/coachProfile');
const { USER_DISPLAY_SELECT, normalizeEnrolledStudents, withDisplayName } = require('../utils/userDisplay');
const {
  sendCoachApplicationApprovedEmail,
  sendCoachApplicationRejectedEmail,
} = require('../utils/emailService');


// ── Dashboard ──────────────────────────────────────────────────────────────
async function getDashboardStats(req, res) {
  try {
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  const memberFilter = await buildMemberUserFilter();
  const activeMemberFilter = await buildMemberUserFilter({ status: 'active' });
  const growthFilter = await buildMemberUserFilter({ createdAt: { $gte: thirtyDaysAgo } });

  const [
    totalUsers, activeUsers, totalCoaches, totalAssignments, totalMeals, totalActivities,
    calAgg, waterAgg, userGrowth, recentSignups,
    totalAppointments, pendingAppointments,
    totalDietPlans, activeDietPlans, dietAdherenceCount, completedWorkouts, pendingExercises,
    pendingCoachApplications,
  ] = await Promise.all([
    User.countDocuments(memberFilter),
    User.countDocuments(activeMemberFilter),
    User.countDocuments({ role: 'coach', status: { $ne: 'deleted' } }),
    CoachAssignment.countDocuments({ status: 'active' }),
    MealLog.countDocuments(),
    ActivityLog.countDocuments(),
    ActivityLog.aggregate([
      { $group: { _id: null, total: { $sum: '$caloriesBurned' } } },
    ]),
    WaterLog.aggregate([
      { $group: { _id: null, total: { $sum: '$amountMl' } } },
    ]),
    User.aggregate([
      { $match: growthFilter },
      { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, count: { $sum: 1 } } },
      { $sort: { _id: 1 } },
    ]),
    User.find(await buildMemberUserFilter())
      .sort({ createdAt: -1 })
      .limit(8)
      .select('username full_name createdAt created_by')
      .lean(),
    Appointment.countDocuments(),
    Appointment.countDocuments({ status: 'pending' }),
    DietPlan.countDocuments(),
    DietPlan.countDocuments({ status: 'active' }),
    DietAdherence.countDocuments(),
    WorkoutCompletion.countDocuments({ status: 'completed' }),
    ActivityLog.countDocuments({ status: 'pending' }),
    CoachApplication.countDocuments({ status: 'pending' }),
  ]);

  const mealCalAgg = await MealLog.aggregate([
    { $group: { _id: null, total: { $sum: '$calories' } } },
  ]);

  res.json({
    totalUsers,
    activeUsers,
    totalCoaches,
    totalAssignments,
    totalMeals,
    totalActivities,
    totalCaloriesBurned: calAgg[0]?.total || 0,
    totalCaloriesConsumed: mealCalAgg[0]?.total || 0,
    totalWaterMl: waterAgg[0]?.total || 0,
    totalAppointments,
    pendingAppointments,
    totalDietPlans,
    activeDietPlans,
    dietAdherenceCount,
    completedWorkouts,
    pendingExercises,
    pendingCoachApplications,
    userGrowth,
    recentSignups: recentSignups.map((u) => ({
      _id: u._id,
      full_name: u.full_name || '',
      username: u.username || '',
      createdAt: u.createdAt,
      self_registered: !u.created_by,
    })),
  });
  } catch (error) {
    console.error('getDashboardStats:', error.message);
    return res.status(500).json({ message: 'Failed to load dashboard statistics' });
  }
}

// ── Users ──────────────────────────────────────────────────────────────────
async function getUsers(req, res) {
  try {
    const { q, status } = req.query;
    const extra = {};

    if (status) {
      extra.status = status;
    }

    const filter = await buildMemberUserFilter(extra);

    if (q) {
      filter.$or = [
        { username: { $regex: q, $options: 'i' } },
        { full_name: { $regex: q, $options: 'i' } },
        { phone: { $regex: q, $options: 'i' } },
      ];
    }

    const users = await User.find(filter)
      .select('-password -admin_password')
      .populate('clientData.assigned_coach_id', 'username full_name')
      .sort({ full_name: 1 })
      .lean();

    // View-only monitoring — never expose credentials to admins.
    const items = users.filter((u) => u.role === 'user');

    return res.json({
      items,
      total: items.length,
      role: 'user',
    });
  } catch (error) {
    console.error('getUsers:', error.message);
    return res.status(500).json({ message: 'Failed to load users' });
  }
}

const ADMIN_MEMBER_MGMT_FORBIDDEN =
  'Admins cannot create, edit, suspend, assign, or reset passwords for member accounts. Members manage their own profiles; coaches manage only members who selected them and were accepted. Admins may delete member accounts when necessary.';

async function createUser(_req, res) {
  return res.status(403).json({
    message:
      'Admins cannot create user or coach accounts. Members and coaches register in the Vital Fitness app. Admins only approve or reject coach applications and may delete accounts when necessary.',
  });
}

async function deleteUser(req, res) {
  try {
    const target = await User.findById(req.params.id);
    if (!target) return res.status(404).json({ message: 'User not found' });
    if (target.role === 'admin') {
      return res.status(403).json({ message: 'Admin accounts cannot be deleted' });
    }
    if (target.role === 'coach') {
      return res.status(400).json({
        message: 'Coach accounts must be deleted from the Coaches page',
      });
    }
    if (target.role !== 'user') {
      return res.status(400).json({ message: 'Only member accounts can be deleted from this endpoint' });
    }

    const userId = target._id;
    const username = target.username;
    const result = await purgeUserAccount(userId);
    if (!result.deleted) {
      return res.status(404).json({ message: 'User not found' });
    }

    try {
      await AuditLog.create({
        actor_id: req.user._id,
        action: 'DELETE_USER',
        target_type: 'User',
        target_id: userId,
        details: { username, role: 'user', permanent: true },
      });
    } catch (auditError) {
      console.warn('deleteUser audit log skipped:', auditError.message);
    }

    return res.json({
      message: 'User permanently deleted',
      deletedId: String(userId),
    });
  } catch (error) {
    console.error('deleteUser:', error.message);
    return res.status(500).json({ message: 'Failed to delete user' });
  }
}

async function updateUserRole(_req, res) {
  return res.status(403).json({ message: ADMIN_MEMBER_MGMT_FORBIDDEN });
}

async function updateUser(_req, res) {
  return res.status(403).json({ message: ADMIN_MEMBER_MGMT_FORBIDDEN });
}

async function updateUserStatus(_req, res) {
  return res.status(403).json({ message: ADMIN_MEMBER_MGMT_FORBIDDEN });
}

async function getUserDetail(req, res) {
  try {
    const user = await User.findById(req.params.id, '-password')
      .populate('clientData.assigned_coach_id', 'username full_name phone status')
      .lean();
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    if (user.role === 'coach') {
      return res.status(400).json({
        message: 'This account is a coach. Use the coach profile endpoint.',
        code: 'ROLE_COACH',
      });
    }
    if (user.role !== 'user') {
      return res.status(403).json({ message: 'Only member profiles can be loaded from this endpoint' });
    }

    const coaching = { assignedCoach: null, clients: [], activeClientCount: 0 };
    const assignment = await CoachAssignment.findOne({ user: user._id, status: 'active' })
      .populate({
        path: 'coach',
        select: 'username full_name phone status role createdAt coachData',
      })
      .lean();
    if (assignment?.coach) {
      coaching.assignedCoach = {
        ...assignment.coach,
        assignedAt: assignment.createdAt,
      };
    } else if (user.clientData?.assigned_coach_id) {
      coaching.assignedCoach = user.clientData.assigned_coach_id;
    }

    const coachApplication = await CoachApplication.findOne({ user: user._id }).lean();

    // Return the stored member document as-is (registration + later self-updates).
    // Do not synthesize coach/profile fields for member accounts.
    return res.json({
      user,
      coachApplication: coachApplication || null,
      coaching,
    });
  } catch (error) {
    console.error('getUserDetail:', error.message);
    return res.status(500).json({ message: 'Failed to load user details' });
  }
}

async function getCoachDetail(req, res) {
  try {
    const coach = await User.findById(req.params.id, '-password').populate('profile').lean();
    if (!coach) {
      return res.status(404).json({ message: 'Coach not found' });
    }
    if (coach.role === 'user') {
      return res.status(400).json({
        message: 'This account is a member. Use the user profile endpoint.',
        code: 'ROLE_USER',
      });
    }
    if (coach.role !== 'coach') {
      return res.status(403).json({ message: 'Only coach profiles can be loaded from this endpoint' });
    }

    const coachApplication = await CoachApplication.findOne({ user: coach._id }).lean();

    const clientAssignments = await CoachAssignment.find({ coach: coach._id, status: 'active' })
      .populate('user', 'username full_name phone status createdAt clientData')
      .sort({ updatedAt: -1 })
      .lean();

    const clients = await Promise.all(
      clientAssignments.map(async (assignment) => {
        const userId = assignment.user?._id;
        const [meals, activities, water, appointments] = await Promise.all([
          MealLog.find({ user: userId }).sort({ date: -1 }).limit(7).lean(),
          ActivityLog.find({ user: userId }).sort({ date: -1 }).limit(7).lean(),
          WaterLog.find({ user: userId }).sort({ date: -1 }).limit(7).lean(),
          Appointment.find({
            $or: [{ client: userId, coach: coach._id }, { user_id: userId, coach_id: coach._id }],
          })
            .sort({ dateTime: -1 })
            .limit(10)
            .lean(),
        ]);
        const approved = activities.filter((a) => a.status === 'approved');
        const caloriesIn = meals.reduce((s, m) => s + (m.calories || 0), 0);
        const caloriesOut = approved.reduce((s, a) => s + (a.caloriesBurned || 0), 0);
        const hydration = water.reduce((s, w) => s + (w.amountMl || 0), 0);
        const completedAppts = appointments.filter((a) => a.status === 'completed').length;
        const upcomingAppts = appointments.filter(
          (a) => ['pending', 'approved', 'rescheduled'].includes(a.status) && new Date(a.dateTime || a.datetime) >= new Date(),
        ).length;

        return {
          _id: userId,
          full_name: assignment.user?.full_name,
          username: assignment.user?.username,
          phone: assignment.user?.phone,
          status: assignment.user?.status,
          memberSince: assignment.user?.createdAt,
          assignedAt: assignment.createdAt,
          weightKg: assignment.user?.clientData?.weight ?? null,
          fitness_goal: assignment.user?.clientData?.fitness_goal || '',
          progress: {
            caloriesIn,
            caloriesOut,
            hydration,
            logCount: meals.length + activities.length + water.length,
            completedAppointments: completedAppts,
            upcomingAppointments: upcomingAppts,
          },
          recentAppointments: appointments.slice(0, 5).map((a) => ({
            _id: a._id,
            dateTime: a.dateTime || a.datetime,
            status: a.status,
            type: a.type,
          })),
        };
      }),
    );

    const teaching = await FitnessClass.find({ coach: coach._id })
      .select('title category date status durationMinutes capacity enrolledStudents')
      .sort({ date: -1 })
      .lean()
      .then((items) =>
        items.map((item) => ({
          ...item,
          enrolledCount: item.enrolledStudents?.length || 0,
        })),
      );

    return res.json({
      user: enrichCoachUser(coach, coachApplication),
      coachApplication,
      coaching: {
        assignedCoach: null,
        clients,
        activeClientCount: clients.length,
      },
      activity: { totalLogs: 0, totalCalories: 0, totalMinutes: 0, recentLogs: [] },
      tracking: { mealLogs: 0, waterLogs: 0 },
      classes: { enrolled: [], teaching },
    });
  } catch (error) {
    console.error('getCoachDetail:', error.message);
    return res.status(500).json({ message: 'Failed to load coach details' });
  }
}

async function getAdminMe(req, res) {
  // Already authenticated as admin via route middleware
  return res.json({
    user: {
      _id: req.user._id,
      username: req.user.username,
      full_name: req.user.full_name,
      role: req.user.role,
      status: req.user.status,
    },
  });
}

// ── Trainers (coaches) ─────────────────────────────────────────────────────
async function getTrainers(req, res) {
  try {
    const [trainers, applications] = await Promise.all([
      User.find({ role: 'coach', status: { $ne: 'deleted' } })
        .select('-password -admin_password')
        .sort({ full_name: 1, username: 1 })
        .lean(),
      CoachApplication.find({})
        .populate('user', '-password')
        .sort({ createdAt: -1 })
        .lean(),
    ]);

    const applicationByUserId = new Map();
    for (const app of applications) {
      const uid = String(app.user?._id || app.user || '');
      if (!uid) continue;
      // Prefer the newest application per user (already sorted desc).
      if (!applicationByUserId.has(uid)) {
        applicationByUserId.set(uid, app);
      }
    }

    const coachIds = trainers.map((trainer) => trainer._id);
    const activeCounts = coachIds.length
      ? await CoachAssignment.aggregate([
        { $match: { coach: { $in: coachIds }, status: 'active' } },
        { $group: { _id: '$coach', activeClients: { $sum: 1 } } },
      ])
      : [];
    const countByCoach = new Map(
      activeCounts.map((row) => [String(row._id), row.activeClients]),
    );

    const seen = new Set();
    const items = [];

    for (const trainer of trainers) {
      const id = String(trainer._id);
      seen.add(id);
      const application = applicationByUserId.get(id) || null;
      const enriched = enrichCoachUser(trainer, application);
      const approval =
        enriched.coachData?.approval_status
        || application?.status
        || 'approved';
      items.push({
        ...enriched,
        activeClients: countByCoach.get(id) || 0,
        approval_status: approval,
        applicationStatus: application?.status || null,
        applicationId: application?._id || null,
        photoUrl: enriched.profile?.photoUrl || enriched.avatar || '',
        specialization: enriched.profile?.specialization || [],
      });
    }

    // Include pending applicants who are not yet role=coach so All Coaches
    // reflects everyone in the coach pipeline.
    for (const app of applications) {
      if (app.status !== 'pending' || !app.user) continue;
      const applicant = typeof app.user === 'object' ? app.user : null;
      if (!applicant?._id) continue;
      const id = String(applicant._id);
      if (seen.has(id)) continue;
      seen.add(id);
      const enriched = enrichCoachUser(
        {
          ...applicant,
          role: applicant.role || 'user',
          coachData: applicant.coachData || { approval_status: 'pending' },
        },
        app,
      );
      items.push({
        ...enriched,
        activeClients: 0,
        approval_status: 'pending',
        applicationStatus: 'pending',
        applicationId: app._id,
        photoUrl: enriched.profile?.photoUrl || enriched.avatar || '',
        specialization: enriched.profile?.specialization || [],
        status: enriched.status || 'active',
      });
    }

    items.sort((a, b) => {
      const an = String(a.full_name || a.username || '').toLowerCase();
      const bn = String(b.full_name || b.username || '').toLowerCase();
      return an.localeCompare(bn);
    });

    return res.json({
      items,
      total: items.length,
      coachAccounts: trainers.length,
      pendingApplicants: items.filter((i) => i.applicationStatus === 'pending' && i.role !== 'coach').length,
    });
  } catch (error) {
    console.error('getTrainers:', error.message);
    return res.status(500).json({ message: 'Failed to load coaches' });
  }
}

async function deleteCoach(req, res) {
  try {
    const coach = await User.findById(req.params.id);
    if (!coach) {
      return res.status(404).json({ message: 'Coach not found' });
    }
    if (coach.role === 'admin') {
      return res.status(403).json({ message: 'Admin accounts cannot be deleted' });
    }

    // Allow deleting approved coaches and pending applicants in the coach pipeline.
    if (coach.role !== 'coach') {
      const application = await CoachApplication.findOne({ user: coach._id }).lean();
      if (!application) {
        return res.status(400).json({
          message: 'Only coach accounts or coach applicants can be deleted from this endpoint',
        });
      }
    }

    const coachId = coach._id;
    const username = coach.username;
    const role = coach.role;
    const result = await purgeUserAccount(coachId);
    if (!result.deleted) {
      return res.status(404).json({ message: 'Coach not found' });
    }

    try {
      await AuditLog.create({
        actor_id: req.user._id,
        action: 'DELETE_COACH',
        target_type: 'User',
        target_id: coachId,
        details: { username, role, permanent: true },
      });
    } catch (auditError) {
      console.warn('deleteCoach audit log skipped:', auditError.message);
    }

    return res.json({
      message: 'Coach permanently deleted',
      deletedId: String(coachId),
    });
  } catch (error) {
    console.error('deleteCoach:', error.message);
    return res.status(500).json({ message: 'Failed to delete coach' });
  }
}

// ── Workout tracker ────────────────────────────────────────────────────────
async function getWorkoutStats(req, res) {
  const [totalActivities, calAgg, durationAgg, recentLogs] = await Promise.all([
    ActivityLog.countDocuments(),
    ActivityLog.aggregate([{ $group: { _id: null, total: { $sum: '$caloriesBurned' } } }]),
    ActivityLog.aggregate([{ $group: { _id: null, avg: { $avg: '$durationMinutes' } } }]),
    ActivityLog.find()
      .sort({ createdAt: -1 })
      .limit(20)
      .populate('user', USER_DISPLAY_SELECT)
      .lean(),
  ]);
  res.json({
    totalActivities,
    totalCaloriesBurned: calAgg[0]?.total || 0,
    avgDurationMinutes: Math.round(durationAgg[0]?.avg || 0),
    recentLogs,
  });
}

// ── Exercises (activity types from logs) ─────────────────────────────────
async function getExerciseTypes(req, res) {
  const [types, pendingLogs, rejectedLogs, approvedLogs] = await Promise.all([
    ActivityLog.aggregate([
      { $group: {
          _id: '$activityType',
          count: { $sum: 1 },
          avgCalories: { $avg: '$caloriesBurned' },
          avgDuration: { $avg: '$durationMinutes' },
          pending: { $sum: { $cond: [{ $eq: ['$status', 'pending'] }, 1, 0] } },
          approved: { $sum: { $cond: [{ $eq: ['$status', 'approved'] }, 1, 0] } },
          rejected: { $sum: { $cond: [{ $eq: ['$status', 'rejected'] }, 1, 0] } },
      }},
      { $sort: { count: -1 } },
    ]),
    ActivityLog.find({ status: 'pending' })
      .populate('user', USER_DISPLAY_SELECT)
      .sort({ createdAt: -1 })
      .lean(),
    ActivityLog.find({ status: 'rejected' })
      .populate('user', USER_DISPLAY_SELECT)
      .sort({ updatedAt: -1 })
      .lean(),
    ActivityLog.find({ status: 'approved' })
      .populate('user', USER_DISPLAY_SELECT)
      .sort({ updatedAt: -1 })
      .lean(),
  ]);
  res.json({ types, pendingLogs, rejectedLogs, approvedLogs });
}

async function approveExercise(req, res) {
  try {
    const log = await ActivityLog.findByIdAndUpdate(
      req.params.id,
      { $set: { status: 'approved' } },
      { new: true, runValidators: true },
    ).populate('user', USER_DISPLAY_SELECT).lean();
    if (!log) return res.status(404).json({ message: 'Log not found' });
    res.json(log);
  } catch (err) {
    res.status(500).json({ message: 'Failed to approve exercise' });
  }
}

async function rejectExercise(req, res) {
  try {
    const log = await ActivityLog.findByIdAndUpdate(
      req.params.id,
      { $set: { status: 'rejected' } },
      { new: true, runValidators: true },
    ).populate('user', USER_DISPLAY_SELECT).lean();
    if (!log) return res.status(404).json({ message: 'Log not found' });
    res.json(log);
  } catch (err) {
    res.status(500).json({ message: 'Failed to reject exercise' });
  }
}

async function rejectExerciseType(req, res) {
  try {
    const { type } = req.params;
    await ActivityLog.updateMany(
      { activityType: type },
      { $set: { status: 'rejected' } },
    );
    res.json({ message: `Successfully rejected all logs for exercise type: ${type}` });
  } catch (err) {
    res.status(500).json({ message: 'Failed to reject exercise type' });
  }
}

async function deleteExerciseType(req, res) {
  try {
    const { type } = req.params;
    await ActivityLog.deleteMany({ activityType: type });
    res.json({ message: `Successfully deleted all logs for exercise type: ${type}` });
  } catch (err) {
    res.status(500).json({ message: 'Failed to delete exercise type' });
  }
}

// ── Meal plans ─────────────────────────────────────────────────────────────
async function getMealStats(req, res) {
  const [totalMeals, calAgg, recentMeals, topMeals] = await Promise.all([
    MealLog.countDocuments(),
    MealLog.aggregate([{ $group: { _id: null, total: { $sum: '$calories' }, avgProtein: { $avg: '$protein' }, avgCarbs: { $avg: '$carbs' }, avgFats: { $avg: '$fats' } } }]),
    MealLog.find().sort({ createdAt: -1 }).limit(20).populate('user', USER_DISPLAY_SELECT).lean(),
    MealLog.aggregate([
      { $group: { _id: '$mealName', count: { $sum: 1 }, avgCalories: { $avg: '$calories' } } },
      { $sort: { count: -1 } },
      { $limit: 10 },
    ]),
  ]);
  res.json({
    totalMeals,
    totalCalories: calAgg[0]?.total || 0,
    avgProtein: Math.round(calAgg[0]?.avgProtein || 0),
    avgCarbs: Math.round(calAgg[0]?.avgCarbs || 0),
    avgFats: Math.round(calAgg[0]?.avgFats || 0),
    recentMeals,
    topMeals,
  });
}

// ── Schedule / coach–member assignment (admin forbidden) ───────────────────
// Admins only approve/reject coach registrations. Members choose coaches;
// coaches accept/reject those requests.
const ADMIN_ASSIGNMENT_FORBIDDEN_MESSAGE =
  'Admins cannot assign coaches to members or manage coach–member assignments. Members choose an active coach; that coach accepts or rejects the request. Admins only approve or reject coach registrations.';

function forbidAdminCoachAssignment(_req, res) {
  return res.status(403).json({ message: ADMIN_ASSIGNMENT_FORBIDDEN_MESSAGE });
}

const getSchedule = forbidAdminCoachAssignment;
const createAssignment = forbidAdminCoachAssignment;
const updateAssignmentStatus = forbidAdminCoachAssignment;
const deleteAssignment = forbidAdminCoachAssignment;

// ── Classes (FitnessClass) ────────────────────────────────────────────────
function formatFitnessClass(doc) {
  const obj = doc.toObject ? doc.toObject() : doc;
  const enrolled = normalizeEnrolledStudents(obj.enrolledStudents || []);
  return {
    ...obj,
    enrolledStudents: enrolled,
    enrolledCount: enrolled.length,
  };
}

async function getClasses(req, res) {
  try {
    const classes = await FitnessClass.find()
      .populate('coach', USER_DISPLAY_SELECT)
      .populate('enrolledStudents', USER_DISPLAY_SELECT)
      .sort({ date: 1 })
      .lean();
    return res.json(classes.map(formatFitnessClass));
  } catch (error) {
    return res.status(500).json({ message: 'Error fetching classes' });
  }
}

async function createClass(req, res) {
  try {
    const { title, description, category, date, durationMinutes, capacity, coachId } = req.body;
    if (!title || !date || !coachId) {
      return res.status(400).json({ message: 'Title, date, and coach are required' });
    }

    const coach = await User.findOne({ _id: coachId, role: 'coach' });
    if (!coach) return res.status(400).json({ message: 'Invalid coach selected' });

    const fitnessClass = await FitnessClass.create({
      coach: coachId,
      title,
      description: description || '',
      category: category || 'General',
      date,
      durationMinutes: durationMinutes || 60,
      capacity: capacity || 20,
    });

    const populated = await FitnessClass.findById(fitnessClass._id)
      .populate('coach', USER_DISPLAY_SELECT)
      .populate('enrolledStudents', USER_DISPLAY_SELECT);

    return res.status(201).json(formatFitnessClass(populated));
  } catch (error) {
    console.error('admin createClass:', error.message);
    return res.status(500).json({ message: 'Error creating class' });
  }
}

async function updateClass(req, res) {
  try {
    const fitnessClass = await FitnessClass.findById(req.params.id);
    if (!fitnessClass) return res.status(404).json({ message: 'Class not found' });

    const { title, description, category, date, durationMinutes, capacity, status, coachId } = req.body;
    if (title) fitnessClass.title = title;
    if (description !== undefined) fitnessClass.description = description;
    if (category) fitnessClass.category = category;
    if (date) fitnessClass.date = date;
    if (durationMinutes) fitnessClass.durationMinutes = durationMinutes;
    if (capacity) fitnessClass.capacity = capacity;
    if (status) fitnessClass.status = status;
    if (coachId) {
      const coach = await User.findOne({ _id: coachId, role: 'coach' });
      if (!coach) return res.status(400).json({ message: 'Invalid coach selected' });
      fitnessClass.coach = coachId;
    }

    await fitnessClass.save();
    const populated = await FitnessClass.findById(fitnessClass._id)
      .populate('coach', USER_DISPLAY_SELECT)
      .populate('enrolledStudents', USER_DISPLAY_SELECT);
    return res.json(formatFitnessClass(populated));
  } catch (error) {
    return res.status(500).json({ message: 'Error updating class' });
  }
}

async function deleteClass(req, res) {
  try {
    const deleted = await FitnessClass.findByIdAndDelete(req.params.id);
    if (!deleted) return res.status(404).json({ message: 'Class not found' });
    return res.json({ message: 'Class deleted' });
  } catch (error) {
    return res.status(500).json({ message: 'Error deleting class' });
  }
}

async function getCoachApplications(req, res) {
  try {
    // Default to pending so Applications stays focused on review queue.
    const status = req.query.status || 'pending';
    const filter = status === 'all' ? {} : { status };
    const applications = await CoachApplication.find(filter)
      .populate('user', 'username full_name phone status role avatar coachData')
      .sort({ createdAt: -1 })
      .lean();

    const enriched = applications.map((app) => {
      const profile = enrichCoachUser(
        {
          ...(app.user || {}),
          phone: app.user?.phone || app.phone,
          coachData: app.user?.coachData,
        },
        app,
      ).profile;
      return {
        ...app,
        profile,
      };
    });

    return res.json(enriched);
  } catch (error) {
    return res.status(500).json({ message: 'Error fetching coach applications' });
  }
}

function parseSpecialization(value) {
  return String(value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

async function approveCoachApplication(req, res) {
  try {
    const application = await CoachApplication.findById(req.params.id).populate('user');
    if (!application) return res.status(404).json({ message: 'Application not found' });
    if (application.status !== 'pending') {
      return res.status(400).json({ message: 'Application has already been reviewed' });
    }
    if (!application.user) {
      return res.status(400).json({ message: 'Application is missing an applicant user' });
    }

    const { buildCoachDataFromApplication } = require('../utils/coachProfile');
    const existingCoachData = application.user.coachData?.toObject?.()
      || application.user.coachData
      || {};

    const specArray = parseSpecialization(application.specialization);
    const profileData = {
      age: application.age,
      phone: application.phone,
      location: application.location,
      yearsExperience: application.yearsExperience,
      certifications: application.certifications,
      specialization: specArray.length ? specArray : [application.specialization].filter(Boolean),
      bio: application.bio,
      experience: application.experience,
      workingDays: application.workingDays || [],
      appointmentDays: application.appointmentDays || [],
      appointmentDurationMinutes:
        application.appointmentDurationMinutes
        || existingCoachData.appointmentDurationMinutes
        || 60,
      dayAvailability:
        (Array.isArray(application.dayAvailability) && application.dayAvailability.length
          ? application.dayAvailability
          : existingCoachData.dayAvailability)
        || [],
    };

    const coachData = buildCoachDataFromApplication({
      approval_status: 'approved',
      phone: application.phone || application.user.phone || '',
      age: application.age,
      location: application.location,
      yearsExperience: application.yearsExperience,
      certifications: application.certifications,
      specialization: application.specialization,
      bio: application.bio,
      experience: application.experience,
      workingDays: application.workingDays || existingCoachData.availability?.workingDays || [],
      appointmentDays: application.appointmentDays || existingCoachData.availability?.appointmentDays || [],
      dayAvailability:
        (Array.isArray(application.dayAvailability) && application.dayAvailability.length
          ? application.dayAvailability
          : existingCoachData.dayAvailability)
        || [],
      appointmentDurationMinutes:
        application.appointmentDurationMinutes
        || existingCoachData.appointmentDurationMinutes
        || 60,
      workingHoursStart: existingCoachData.availability?.workingHoursStart || '09:00',
      workingHoursEnd: existingCoachData.availability?.workingHoursEnd || '17:00',
    });

    // Promote the user first so a later notification/profile glitch cannot leave a
    // pending card that is already "reviewed" on retry.
    await User.findByIdAndUpdate(
      application.user._id,
      {
        $set: {
          role: 'coach',
          status: 'active',
          phone: application.phone || application.user.phone || '',
          coachData,
        },
      },
      { returnDocument: 'after', runValidators: true },
    );

    const reviewed = await CoachApplication.findOneAndUpdate(
      { _id: application._id, status: 'pending' },
      { $set: { status: 'approved', reviewedAt: new Date() } },
      { new: true },
    );
    if (!reviewed) {
      return res.status(400).json({ message: 'Application has already been reviewed' });
    }

    try {
      if (application.user.profile) {
        await Profile.findByIdAndUpdate(
          application.user.profile,
          { $set: profileData },
          { returnDocument: 'after', runValidators: true },
        );
      } else {
        await Profile.create({ goals: [], ...profileData });
      }
    } catch (profileError) {
      console.error('[ADMIN] coach approve profile sync:', profileError.message);
    }

    try {
      await Notification.create({
        user: application.user._id,
        message: 'Your coach application has been approved! Please log in again to access your coach dashboard.',
        type: 'update',
      });
    } catch (notificationError) {
      console.error('[ADMIN] coach approve notification:', notificationError.message);
    }

    try {
      await sendCoachApplicationApprovedEmail(application.user);
    } catch (emailError) {
      console.error('[EMAIL] Failed to send coach approval email:', emailError.message);
    }

    const payload = await CoachApplication.findById(application._id)
      .populate('user', 'username full_name phone status role')
      .lean();

    return res.json(payload);
  } catch (error) {
    console.error('[ADMIN] Failed to approve application:', error.message);
    return res.status(500).json({ message: 'Failed to approve application' });
  }
}

async function rejectCoachApplication(req, res) {
  try {
    const reason = String(req.body?.reason || '').trim();

    // Claim the pending application so concurrent reviews cannot double-process it.
    const application = await CoachApplication.findOneAndUpdate(
      { _id: req.params.id, status: 'pending' },
      { $set: { status: 'rejected', reviewedAt: new Date() } },
      { new: true },
    ).populate('user');

    if (!application) {
      const existing = await CoachApplication.findById(req.params.id).lean();
      if (!existing) return res.status(404).json({ message: 'Application not found' });
      return res.status(400).json({ message: 'Application has already been reviewed' });
    }

    if (!application.user) {
      return res.status(400).json({ message: 'Application is missing an applicant user' });
    }

    const applicant = application.user;
    if (applicant.role === 'admin') {
      return res.status(403).json({ message: 'Admin accounts cannot be rejected' });
    }

    // Never reject an already-approved coach via the applications flow.
    if (
      applicant.role === 'coach'
      && applicant.coachData?.approval_status === 'approved'
    ) {
      return res.status(400).json({
        message: 'This account is an approved coach. Remove them from the Coaches page instead.',
      });
    }

    const existingCoachData = applicant.coachData?.toObject?.()
      || applicant.coachData
      || {};

    // Keep the member account so applicants can see rejection status and reapply.
    await User.findByIdAndUpdate(
      applicant._id,
      {
        $set: {
          role: 'user',
          coachData: {
            ...existingCoachData,
            approval_status: 'rejected',
          },
        },
      },
      { runValidators: true },
    );

    try {
      await Notification.create({
        user: applicant._id,
        message: reason
          ? `Your coach application was not approved: ${reason}. You can update your details and reapply, or continue as a member.`
          : 'Your coach application was not approved. You can update your details and reapply, or continue as a member.',
        type: 'update',
      });
    } catch (notificationError) {
      console.error('[ADMIN] coach reject notification:', notificationError.message);
    }

    try {
      await sendCoachApplicationRejectedEmail(applicant);
    } catch (emailError) {
      console.error('[EMAIL] Failed to send coach rejection email:', emailError.message);
    }

    try {
      await AuditLog.create({
        actor_id: req.user._id,
        action: 'REJECT_COACH_APPLICATION',
        target_type: 'CoachApplication',
        target_id: application._id,
        details: {
          username: applicant.username,
          full_name: applicant.full_name,
          role: applicant.role,
          reason: reason || undefined,
        },
      });
    } catch (auditError) {
      console.error('[ADMIN] coach reject audit:', auditError.message);
    }

    const payload = await CoachApplication.findById(application._id)
      .populate('user', 'username full_name phone status role')
      .lean();

    return res.json({
      message: 'Coach application rejected',
      status: 'rejected',
      application: payload,
    });
  } catch (error) {
    console.error('[ADMIN] Failed to reject application:', error.message);
    return res.status(500).json({ message: 'Failed to reject application' });
  }
}

async function sendAnnouncement(req, res) {
  try {
    const { title, message, target = 'all' } = req.body;
    if (!message || !message.trim()) {
      return res.status(400).json({ message: 'Message is required' });
    }

    const filter = {};
    if (target === 'users') filter.role = 'user';
    else if (target === 'coaches') filter.role = 'coach';
    else filter.role = { $in: ['user', 'coach'] };

    const users = await User.find(filter).select('_id').lean();
    const fullMessage = title && title.trim() ? `${title.trim()}: ${message.trim()}` : message.trim();

    if (users.length === 0) {
      return res.json({ sent: 0, message: 'No recipients found' });
    }

    await Notification.insertMany(
      users.map((u) => ({
        user: u._id,
        message: fullMessage,
        type: 'system',
      })),
    );

    return res.status(201).json({ sent: users.length, message: `Announcement sent to ${users.length} users` });
  } catch (error) {
    console.error('sendAnnouncement:', error.message);
    return res.status(500).json({ message: 'Failed to send announcement' });
  }
}

// ── Statistics ─────────────────────────────────────────────────────────────
async function getStatistics(req, res) {
  // User sign-ups by day (last 30 days)
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

  const [
    userGrowth,
    activityByType,
    mealsByDay,
    waterByDay,
    appointmentsByStatus,
    weeklyActivity,
    workoutCompletionsByDay,
    dietCompletionsByDay,
  ] = await Promise.all([
    User.aggregate([
      { $match: { role: 'user', createdAt: { $gte: thirtyDaysAgo } } },
      { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, count: { $sum: 1 } } },
      { $sort: { _id: 1 } },
    ]),
    ActivityLog.aggregate([
      { $group: { _id: '$activityType', total: { $sum: '$caloriesBurned' } } },
      { $sort: { total: -1 } },
      { $limit: 6 },
    ]),
    MealLog.aggregate([
      { $match: { createdAt: { $gte: thirtyDaysAgo } } },
      { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, totalCalories: { $sum: '$calories' } } },
      { $sort: { _id: 1 } },
    ]),
    WaterLog.aggregate([
      { $match: { createdAt: { $gte: thirtyDaysAgo } } },
      { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, totalMl: { $sum: '$amountMl' } } },
      { $sort: { _id: 1 } },
    ]),
    Appointment.aggregate([
      { $group: { _id: '$status', count: { $sum: 1 } } },
    ]),
    ActivityLog.aggregate([
      { $match: { createdAt: { $gte: sevenDaysAgo } } },
      {
        $group: {
          _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
          count: { $sum: 1 },
          calories: { $sum: '$caloriesBurned' },
        },
      },
      { $sort: { _id: 1 } },
    ]),
    WorkoutCompletion.aggregate([
      { $match: { status: 'completed', completedAt: { $gte: thirtyDaysAgo } } },
      { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$completedAt' } }, count: { $sum: 1 } } },
      { $sort: { _id: 1 } },
    ]),
    DietAdherence.aggregate([
      { $match: { date: { $gte: thirtyDaysAgo } } },
      { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$date' } }, count: { $sum: 1 } } },
      { $sort: { _id: 1 } },
    ]),
  ]);

  res.json({
    userGrowth,
    activityByType,
    mealsByDay,
    waterByDay,
    appointmentsByStatus,
    weeklyActivity,
    workoutCompletionsByDay,
    dietCompletionsByDay,
  });
}

// ── Appointments (admin overview) ──────────────────────────────────────────
async function getAppointments(req, res) {
  try {
    const { status, q } = req.query;
    const filter = {};
    if (status && status !== 'all') filter.status = status;

    let appointments = await Appointment.find(filter)
      .populate('client', 'username full_name phone')
      .populate('coach', 'username full_name phone')
      .populate('fitnessClass', 'title')
      .sort({ dateTime: -1 })
      .limit(200)
      .lean();

    if (q) {
      const term = String(q).toLowerCase();
      appointments = appointments.filter((a) => {
        const client = `${a.client?.full_name || ''} ${a.client?.username || ''} ${a.client?.phone || ''}`;
        const coach = `${a.coach?.full_name || ''} ${a.coach?.username || ''} ${a.coach?.phone || ''}`;
        return client.toLowerCase().includes(term) || coach.toLowerCase().includes(term);
      });
    }

    const normalized = appointments.map((a) => ({
      ...a,
      dateTime: a.dateTime || a.datetime,
      client: a.client
        ? {
            ...a.client,
            name: a.client.full_name || a.client.username,
            email: a.client.username ? `@${a.client.username}` : '',
          }
        : null,
      coach: a.coach
        ? {
            ...a.coach,
            name: a.coach.full_name || a.coach.username,
            email: a.coach.username ? `@${a.coach.username}` : '',
          }
        : null,
    }));

    return res.json({ appointments: normalized });
  } catch (error) {
    console.error('getAppointments:', error.message);
    return res.status(500).json({ message: 'Failed to load appointments' });
  }
}

// ── Diet plans & adherence ─────────────────────────────────────────────────
async function getAdminDietPlans(req, res) {
  try {
    const { status = 'all', q } = req.query;
    const filter = {};
    if (status && status !== 'all') filter.status = status;

    let plans = await DietPlan.find(filter)
      .populate('coach', USER_DISPLAY_SELECT)
      .populate('client', USER_DISPLAY_SELECT)
      .populate('fitnessClass', 'title')
      .sort({ updatedAt: -1 })
      .limit(200)
      .lean();

    if (q) {
      const term = String(q).toLowerCase();
      plans = plans.filter((p) => {
        const hay = [
          p.title,
          p.coach?.name,
          p.client?.name,
          p.fitnessClass?.title,
        ].join(' ').toLowerCase();
        return hay.includes(term);
      });
    }

    const enriched = plans.map((p) => {
      const coach = withDisplayName(p.coach);
      const client = withDisplayName(p.client);
      const mealSource = p.planType === 'weekly' && Array.isArray(p.days) && p.days.length
        ? p.days.flatMap((d) => d.meals || [])
        : (p.meals || []);
      const mealTypes = [...new Set(
        mealSource
          .map((m) => m?.type)
          .filter(Boolean),
      )];
      return {
        ...p,
        coach,
        client,
        planType: p.planType || 'single_day',
        assigneeType: p.client ? 'user' : 'group',
        assigneeName: client?.name || p.fitnessClass?.title || '—',
        mealTypes,
      };
    });

    return res.json({ plans: enriched });
  } catch (error) {
    console.error('getAdminDietPlans:', error.message);
    return res.status(500).json({ message: 'Failed to load diet plans' });
  }
}

async function getAdminDietAdherence(req, res) {
  try {
    const { userId, days = 14 } = req.query;
    const since = new Date();
    since.setDate(since.getDate() - Number(days));

    const filter = { date: { $gte: since } };
    if (userId) filter.user = userId;

    const records = await DietAdherence.find(filter)
      .populate('user', USER_DISPLAY_SELECT)
      .populate('coach', USER_DISPLAY_SELECT)
      .populate('dietPlan', 'title dailyCalories meals')
      .sort({ date: -1 })
      .limit(300)
      .lean();

    const summary = {
      breakfast: 0,
      lunch: 0,
      dinner: 0,
      snacks: 0,
      totalRecords: records.length,
      avgAdherence: records.length
        ? Math.round(records.reduce((s, r) => s + (r.adherencePercent || 0), 0) / records.length)
        : 0,
    };

    for (const record of records) {
      for (const meal of record.mealAdherence || []) {
        if (meal.followed && summary[meal.type] != null) summary[meal.type] += 1;
      }
    }

    return res.json({ records, summary });
  } catch (error) {
    console.error('getAdminDietAdherence:', error.message);
    return res.status(500).json({ message: 'Failed to load diet adherence' });
  }
}

// ── Workout completions & exercise plans ───────────────────────────────────
async function getAdminWorkouts(req, res) {
  try {
    const [completions, plans, activityStats] = await Promise.all([
      WorkoutCompletion.find()
        .populate('user', USER_DISPLAY_SELECT)
        .populate('coach', USER_DISPLAY_SELECT)
        .populate('exercisePlan', 'title level')
        .sort({ updatedAt: -1 })
        .limit(200)
        .lean(),
      ExercisePlan.find({ status: 'active' })
        .populate('coach', USER_DISPLAY_SELECT)
        .populate('client', USER_DISPLAY_SELECT)
        .populate('fitnessClass', 'title')
        .sort({ updatedAt: -1 })
        .limit(100)
        .lean(),
      getWorkoutStatsPayload(),
    ]);

    return res.json({
      completions,
      plans,
      ...activityStats,
    });
  } catch (error) {
    console.error('getAdminWorkouts:', error.message);
    return res.status(500).json({ message: 'Failed to load workouts' });
  }
}

async function getWorkoutStatsPayload() {
  const [totalActivities, calAgg, durationAgg, recentLogs] = await Promise.all([
    ActivityLog.countDocuments(),
    ActivityLog.aggregate([{ $group: { _id: null, total: { $sum: '$caloriesBurned' } } }]),
    ActivityLog.aggregate([{ $group: { _id: null, avg: { $avg: '$durationMinutes' } } }]),
    ActivityLog.find()
      .sort({ createdAt: -1 })
      .limit(20)
      .populate('user', USER_DISPLAY_SELECT)
      .lean(),
  ]);
  return {
    totalActivities,
    totalCaloriesBurned: calAgg[0]?.total || 0,
    avgDurationMinutes: Math.round(durationAgg[0]?.avg || 0),
    recentLogs,
  };
}

async function getReports(req, res) {
  try {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const [
      waterByDay,
      caloriesByDay,
      weightSeries,
      workoutCompletionsByDay,
      userGrowth,
      activityByType,
      mealsByDay,
    ] = await Promise.all([
      WaterLog.aggregate([
        { $match: { createdAt: { $gte: thirtyDaysAgo } } },
        { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, totalMl: { $sum: '$amountMl' } } },
        { $sort: { _id: 1 } },
      ]),
      MealLog.aggregate([
        { $match: { createdAt: { $gte: thirtyDaysAgo } } },
        { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, totalCalories: { $sum: '$calories' } } },
        { $sort: { _id: 1 } },
      ]),
      DietAdherence.aggregate([
        { $match: { date: { $gte: thirtyDaysAgo }, weightKg: { $ne: null } } },
        { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$date' } }, avgWeight: { $avg: '$weightKg' } } },
        { $sort: { _id: 1 } },
      ]),
      WorkoutCompletion.aggregate([
        { $match: { status: 'completed', completedAt: { $gte: thirtyDaysAgo } } },
        { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$completedAt' } }, count: { $sum: 1 } } },
        { $sort: { _id: 1 } },
      ]),
      User.aggregate([
        { $match: { role: 'user', createdAt: { $gte: thirtyDaysAgo } } },
        { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, count: { $sum: 1 } } },
        { $sort: { _id: 1 } },
      ]),
      ActivityLog.aggregate([
        { $group: { _id: '$activityType', total: { $sum: '$caloriesBurned' } } },
        { $sort: { total: -1 } },
        { $limit: 8 },
      ]),
      MealLog.aggregate([
        { $match: { createdAt: { $gte: thirtyDaysAgo } } },
        { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, totalCalories: { $sum: '$calories' } } },
        { $sort: { _id: 1 } },
      ]),
    ]);

    return res.json({
      userGrowth,
      activityByType,
      mealsByDay: mealsByDay.length ? mealsByDay : caloriesByDay,
      waterByDay,
      weightSeries,
      workoutCompletionsByDay,
      totals: {
        users: await User.countDocuments(await buildMemberUserFilter()),
        coaches: await User.countDocuments({ role: 'coach', status: { $ne: 'deleted' } }),
        appointments: await Appointment.countDocuments(),
        meals: await MealLog.countDocuments(),
        waterMl: (await WaterLog.aggregate([{ $group: { _id: null, total: { $sum: '$amountMl' } } }]))[0]?.total || 0,
        activities: await ActivityLog.countDocuments(),
      },
    });
  } catch (error) {
    console.error('getReports:', error.message);
    return res.status(500).json({ message: 'Failed to load reports' });
  }
}

async function regeneratePassword(_req, res) {
  return res.status(403).json({ message: ADMIN_MEMBER_MGMT_FORBIDDEN });
}

async function getAuditLogs(req, res) {
  try {
    const logs = await AuditLog.find()
      .populate('actor_id', 'username full_name role')
      .sort({ created_at: -1 })
      .limit(200)
      .lean();
    return res.json(logs);
  } catch (error) {
    console.error('getAuditLogs:', error.message);
    return res.status(500).json({ message: 'Failed to load audit logs' });
  }
}

// ── Coaching progress (admin overview of coach ↔ client) ───────────────────
async function getCoachingProgress(req, res) {
  try {
    const assignments = await CoachAssignment.find({ status: 'active' })
      .populate('coach', 'username full_name phone status')
      .populate('user', 'username full_name phone status clientData')
      .sort({ updatedAt: -1 })
      .lean();

    const pairs = await Promise.all(
      assignments.map(async (assignment) => {
        const coachId = assignment.coach?._id;
        const userId = assignment.user?._id;
        if (!coachId || !userId) return null;

        const [meals, activities, water, appointments] = await Promise.all([
          MealLog.find({ user: userId }).sort({ date: -1 }).limit(7).lean(),
          ActivityLog.find({ user: userId }).sort({ date: -1 }).limit(7).lean(),
          WaterLog.find({ user: userId }).sort({ date: -1 }).limit(7).lean(),
          Appointment.find({
            $or: [
              { client: userId, coach: coachId },
              { user_id: userId, coach_id: coachId },
            ],
          })
            .sort({ dateTime: -1 })
            .lean(),
        ]);

        const approved = activities.filter((a) => a.status === 'approved');
        const caloriesIn = meals.reduce((s, m) => s + (m.calories || 0), 0);
        const caloriesOut = approved.reduce((s, a) => s + (a.caloriesBurned || 0), 0);
        const hydration = water.reduce((s, w) => s + (w.amountMl || 0), 0);
        const byStatus = appointments.reduce((acc, a) => {
          acc[a.status] = (acc[a.status] || 0) + 1;
          return acc;
        }, {});

        return {
          assignmentId: assignment._id,
          assignedAt: assignment.createdAt || assignment.assigned_at,
          coach: {
            _id: coachId,
            full_name: assignment.coach.full_name,
            username: assignment.coach.username,
            status: assignment.coach.status,
          },
          client: {
            _id: userId,
            full_name: assignment.user.full_name,
            username: assignment.user.username,
            status: assignment.user.status,
            weightKg: assignment.user.clientData?.weight ?? null,
            fitness_goal: assignment.user.clientData?.fitness_goal || '',
          },
          progress: {
            caloriesIn,
            caloriesOut,
            hydrationMl: hydration,
            logCount: meals.length + activities.length + water.length,
            weightKg: assignment.user.clientData?.weight ?? null,
          },
          appointments: {
            total: appointments.length,
            byStatus,
            upcoming: appointments.filter(
              (a) =>
                ['pending', 'approved', 'rescheduled'].includes(a.status) &&
                new Date(a.dateTime || a.datetime) >= new Date(),
            ).length,
            completed: byStatus.completed || 0,
            next: appointments.find(
              (a) =>
                ['pending', 'approved', 'rescheduled'].includes(a.status) &&
                new Date(a.dateTime || a.datetime) >= new Date(),
            )
              ? {
                  dateTime:
                    appointments.find(
                      (a) =>
                        ['pending', 'approved', 'rescheduled'].includes(a.status) &&
                        new Date(a.dateTime || a.datetime) >= new Date(),
                    ).dateTime ||
                    appointments.find(
                      (a) =>
                        ['pending', 'approved', 'rescheduled'].includes(a.status) &&
                        new Date(a.dateTime || a.datetime) >= new Date(),
                    ).datetime,
                  status: appointments.find(
                    (a) =>
                      ['pending', 'approved', 'rescheduled'].includes(a.status) &&
                      new Date(a.dateTime || a.datetime) >= new Date(),
                  ).status,
                }
              : null,
          },
        };
      }),
    );

    return res.json({
      pairs: pairs.filter(Boolean),
      total: pairs.filter(Boolean).length,
    });
  } catch (error) {
    console.error('getCoachingProgress:', error.message);
    return res.status(500).json({ message: 'Failed to load coaching progress' });
  }
}

module.exports = {
  getDashboardStats,
  getUsers, getUserDetail, getCoachDetail, getAdminMe, createUser, deleteUser, updateUserRole, updateUser, updateUserStatus,
  getTrainers, deleteCoach,
  getWorkoutStats,
  getExerciseTypes, approveExercise, rejectExercise, rejectExerciseType, deleteExerciseType,
  getMealStats,
  getSchedule, createAssignment, updateAssignmentStatus, deleteAssignment,
  getClasses, createClass, updateClass, deleteClass,
  getStatistics,
  sendAnnouncement,
  getCoachApplications,
  approveCoachApplication,
  rejectCoachApplication,
  getAppointments,
  getCoachingProgress,
  getAdminDietPlans,
  getAdminDietAdherence,
  getAdminWorkouts,
  getReports,
  regeneratePassword,
  getAuditLogs,
};
