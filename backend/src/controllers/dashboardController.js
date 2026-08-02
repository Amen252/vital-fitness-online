const mongoose = require('mongoose');
const User = require('../models/User');
const CoachClientAssignment = require('../models/CoachClientAssignment');
const WorkoutPlan = require('../models/WorkoutPlan');
const WorkoutLog = require('../models/WorkoutLog');
const DailyTracking = require('../models/DailyTracking');
const AuditLog = require('../models/AuditLog');
const Appointment = require('../models/Appointment');
const CoachApplication = require('../models/CoachApplication');
const { buildMemberUserFilter } = require('../utils/memberUserQuery');

// Legacy ActivityLog import for backwards compatibility metrics
let ActivityLog;
try {
  ActivityLog = require('../models/ActivityLog');
} catch (e) {
  // ActivityLog might not exist or be needed
}

async function getAdminDashboard(req, res) {
  try {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const memberFilter = await buildMemberUserFilter();
    const activeMemberFilter = await buildMemberUserFilter({ status: 'active' });
    const growthFilter = await buildMemberUserFilter({ createdAt: { $gte: thirtyDaysAgo } });

    const [
      totalUsersCount,
      activeUsersCount,
      totalCoachesCount,
      activeAssignmentsCount,
      pendingApplications,
      appointmentsGrouped,
      recentAuditLogs,
      pendingExercisesCount
    ] = await Promise.all([
      User.countDocuments(memberFilter),
      User.countDocuments(activeMemberFilter),
      User.countDocuments({ role: 'coach', status: { $ne: 'deleted' } }),
      CoachClientAssignment.countDocuments({ status: 'active' }),
      CoachApplication.find({ status: 'pending' }).populate('user', 'username full_name').lean(),
      Appointment.aggregate([
        { $group: { _id: '$status', count: { $sum: 1 } } }
      ]),
      AuditLog.find()
        .populate('actor_id', 'username full_name')
        .sort({ created_at: -1 })
        .limit(10)
        .lean(),
      ActivityLog ? ActivityLog.countDocuments({ status: 'pending' }) : Promise.resolve(0)
    ]);

    // Format appointments grouped count
    const appointmentsStats = {
      pending: 0,
      confirmed: 0,
      completed: 0,
      cancelled: 0,
      no_show: 0
    };
    appointmentsGrouped.forEach(group => {
      if (appointmentsStats[group._id] !== undefined) {
        appointmentsStats[group._id] = group.count;
      }
    });

    // User growth by day (last 30 days)
    const userGrowth = await User.aggregate([
      { $match: growthFilter },
      { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, count: { $sum: 1 } } },
      { $sort: { _id: 1 } }
    ]);

    return res.json({
      stats: {
        totalUsers: totalUsersCount,
        activeUsers: activeUsersCount,
        totalCoaches: totalCoachesCount,
        activeAssignments: activeAssignmentsCount,
        pendingExercises: pendingExercisesCount
      },
      userGrowth,
      pendingApplications,
      appointmentsStats,
      recentAuditLogs
    });
  } catch (error) {
    console.error('[DASHBOARD] Admin error:', error);
    return res.status(500).json({ message: 'Failed to load admin dashboard data' });
  }
}

async function getCoachDashboard(req, res) {
  try {
    const coachId = req.user._id;

    // Fetch assigned clients
    const assignments = await CoachClientAssignment.find({ coach_id: coachId, status: 'active' })
      .populate('user_id', 'username full_name phone clientData')
      .lean();

    const clientIds = assignments.map(a => a.user_id?._id).filter(Boolean);

    // Fetch coach's appointments
    const appointments = await Appointment.find({ coach_id: coachId })
      .populate('user_id', 'username full_name phone')
      .sort({ datetime: 1 })
      .lean();

    // Fetch recent daily tracking metrics for assigned clients
    const dailyTrackings = await DailyTracking.find({
      user_id: { $in: clientIds },
      date: { $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) } // last 7 days
    })
      .populate('user_id', 'username full_name')
      .sort({ date: -1 })
      .lean();

    // Fetch client workout logs
    const workoutLogs = await WorkoutLog.find({
      user_id: { $in: clientIds }
    })
      .populate('user_id', 'username full_name')
      .sort({ date: -1 })
      .limit(20)
      .lean();

    return res.json({
      assignments: assignments.map(a => ({
        id: a._id,
        user: a.user_id,
        assigned_at: a.assigned_at,
        status: a.status
      })),
      appointments,
      clientProgress: {
        dailyTrackings,
        workoutLogs
      }
    });
  } catch (error) {
    console.error('[DASHBOARD] Coach error:', error);
    return res.status(500).json({ message: 'Failed to load coach dashboard data' });
  }
}

async function getUserDashboard(req, res) {
  try {
    const userId = req.user._id;
    const CoachAssignment = require('../models/CoachAssignment');
    const { ensureLegacyCoachAssignment } = require('../utils/coachVisibility');

    // Prefer modern assignment; fall back to legacy CoachAssignment for older records.
    let assignment = await CoachClientAssignment.findOne({ user_id: userId, status: 'active' })
      .populate('coach_id', 'username full_name phone coachData')
      .lean();

    if (!assignment) {
      const legacy = await CoachAssignment.findOne({ user: userId, status: 'active' })
        .populate('coach', 'username full_name phone coachData')
        .lean();
      if (legacy?.coach) {
        assignment = {
          _id: legacy._id,
          coach_id: legacy.coach,
          assigned_at: legacy.createdAt || legacy.updatedAt,
        };
      }
    } else {
      const modernCoachId = assignment.coach_id?._id || assignment.coach_id;
      if (modernCoachId) {
        try {
          await ensureLegacyCoachAssignment(modernCoachId, userId);
        } catch (syncError) {
          console.error('[DASHBOARD] legacy assignment sync:', syncError.message);
        }
      }
    }

    // Fetch upcoming appointments
    const appointments = await Appointment.find({ user_id: userId })
      .populate('coach_id', 'username full_name phone')
      .sort({ datetime: 1 })
      .lean();

    // Fetch current workout plans
    const workoutPlans = await WorkoutPlan.find({ assigned_to: userId })
      .sort({ start_date: -1 })
      .lean();

    // Fetch daily tracking metrics (last 30 days)
    const dailyTrackings = await DailyTracking.find({ user_id: userId })
      .sort({ date: -1 })
      .limit(30)
      .lean();

    // Fetch workout logs (last 30 days)
    const workoutLogs = await WorkoutLog.find({ user_id: userId })
      .sort({ date: -1 })
      .limit(30)
      .lean();

    return res.json({
      assignedCoach: assignment ? {
        assignmentId: assignment._id,
        coach: assignment.coach_id,
        assigned_at: assignment.assigned_at
      } : null,
      appointments,
      workoutPlans,
      dailyTrackings,
      workoutLogs,
      weightHistory: req.user.clientData?.weight_history || []
    });
  } catch (error) {
    console.error('[DASHBOARD] User error:', error);
    return res.status(500).json({ message: 'Failed to load user dashboard data' });
  }
}

module.exports = {
  getAdminDashboard,
  getCoachDashboard,
  getUserDashboard
};
