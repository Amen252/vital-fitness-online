const mongoose = require('mongoose');
const User = require('../models/User');
const Profile = require('../models/Profile');
const CoachAssignment = require('../models/CoachAssignment');
const CoachClientAssignment = require('../models/CoachClientAssignment');
const CoachRequest = require('../models/CoachRequest');
const CoachApplication = require('../models/CoachApplication');
const Review = require('../models/Review');
const Notification = require('../models/Notification');
const Message = require('../models/Message');
const Session = require('../models/Session');
const Appointment = require('../models/Appointment');
const FitnessClass = require('../models/FitnessClass');
const DietPlan = require('../models/DietPlan');
const DietAdherence = require('../models/DietAdherence');
const ExercisePlan = require('../models/ExercisePlan');
const WorkoutTemplate = require('../models/WorkoutTemplate');
const WeeklyWorkoutPlan = require('../models/WeeklyWorkoutPlan');
const WorkoutSchedule = require('../models/WorkoutSchedule');
const WorkoutCompletion = require('../models/WorkoutCompletion');
const Schedule = require('../models/Schedule');
const ScheduleCompletion = require('../models/ScheduleCompletion');
const ActivityLog = require('../models/ActivityLog');
const WaterLog = require('../models/WaterLog');
const MealLog = require('../models/MealLog');
const ShareCard = require('../models/ShareCard');
const InviteCode = require('../models/InviteCode');
const DailyTracking = require('../models/DailyTracking');
const WorkoutLog = require('../models/WorkoutLog');
const WorkoutPlan = require('../models/WorkoutPlan');
const Article = require('../models/Article');

/**
 * Permanently remove a user/coach account and all related records.
 * Does not delete admin accounts — callers must enforce that guard.
 */
async function purgeUserAccount(userId) {
  const id = new mongoose.Types.ObjectId(String(userId));

  await Promise.all([
    CoachAssignment.deleteMany({ $or: [{ coach: id }, { user: id }] }),
    CoachClientAssignment.deleteMany({ $or: [{ coach_id: id }, { user_id: id }] }),
    CoachRequest.deleteMany({ $or: [{ coach: id }, { user: id }] }),
    CoachApplication.deleteMany({ user: id }),
    Review.deleteMany({ $or: [{ coach: id }, { client: id }] }),
    Notification.deleteMany({ $or: [{ user: id }, { recipient_id: id }] }),
    Message.deleteMany({ $or: [{ sender: id }, { receiver: id }] }),
    Session.deleteMany({ $or: [{ coach: id }, { client: id }] }),
    Appointment.deleteMany({
      $or: [{ coach: id }, { client: id }, { user_id: id }, { coach_id: id }],
    }),
    FitnessClass.deleteMany({ coach: id }),
    DietPlan.deleteMany({ $or: [{ coach: id }, { client: id }] }),
    DietAdherence.deleteMany({ $or: [{ coach: id }, { user: id }] }),
    ExercisePlan.deleteMany({ $or: [{ coach: id }, { client: id }] }),
    WorkoutTemplate.deleteMany({ coach: id }),
    WeeklyWorkoutPlan.deleteMany({ $or: [{ coach: id }, { client: id }] }),
    WorkoutSchedule.deleteMany({ $or: [{ coach: id }, { client: id }] }),
    WorkoutCompletion.deleteMany({ $or: [{ coach: id }, { user: id }] }),
    Schedule.deleteMany({ $or: [{ coach: id }, { client: id }] }),
    ScheduleCompletion.deleteMany({ $or: [{ coach: id }, { user: id }] }),
    ActivityLog.deleteMany({ user: id }),
    WaterLog.deleteMany({ user: id }),
    MealLog.deleteMany({ user: id }),
    ShareCard.deleteMany({ user_id: id }),
    InviteCode.deleteMany({ owner_id: id }),
    DailyTracking.deleteMany({ user_id: id }),
    WorkoutLog.deleteMany({ user_id: id }),
    WorkoutPlan.deleteMany({ $or: [{ created_by: id }, { assigned_to: id }] }),
  ]);

  await Promise.all([
    User.updateMany(
      { 'clientData.assigned_coach_id': id },
      { $set: { 'clientData.assigned_coach_id': null } },
    ),
    User.updateMany({ invited_by: id }, { $set: { invited_by: null } }),
    FitnessClass.updateMany({ enrolledStudents: id }, { $pull: { enrolledStudents: id } }),
    FitnessClass.updateMany(
      { 'attendance.student': id },
      { $pull: { attendance: { student: id } } },
    ),
    Article.updateMany(
      { 'groups.students': id },
      { $pull: { 'groups.$[group].students': id } },
      { arrayFilters: [{ 'group.students': id }] },
    ),
  ]);

  const user = await User.findById(id).select('profile role').lean();
  if (!user) {
    return { deleted: false, reason: 'not_found' };
  }

  const profileId = user.profile;
  await User.findByIdAndDelete(id);
  if (profileId) {
    await Profile.findByIdAndDelete(profileId);
  }

  return { deleted: true, role: user.role };
}

module.exports = { purgeUserAccount };
