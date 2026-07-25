const ExercisePlan = require('../models/ExercisePlan');
const WorkoutCompletion = require('../models/WorkoutCompletion');
const WorkoutSchedule = require('../models/WorkoutSchedule');
const ScheduleCompletion = require('../models/ScheduleCompletion');

/**
 * When a member joins a class, create missing completion rows so they can see
 * and complete active group exercise plans and schedules assigned to that class.
 */
async function backfillGroupPlanAccess(userId, classIds) {
  const ids = (Array.isArray(classIds) ? classIds : [classIds])
    .filter(Boolean)
    .map((id) => id._id || id);
  if (!userId || !ids.length) return;

  const [exercisePlans, schedules] = await Promise.all([
    ExercisePlan.find({ fitnessClass: { $in: ids }, status: 'active' })
      .select('_id coach dueDate')
      .lean(),
    WorkoutSchedule.find({
      fitnessClass: { $in: ids },
      status: { $in: ['scheduled', 'completed'] },
    })
      .select('_id coach')
      .lean(),
  ]);

  await Promise.all([
    ...exercisePlans.map((plan) =>
      WorkoutCompletion.create({
        exercisePlan: plan._id,
        user: userId,
        coach: plan.coach,
        dueDate: plan.dueDate,
        status: 'pending',
      }).catch((err) => {
        if (err.code !== 11000) throw err;
      }),
    ),
    ...schedules.map((schedule) =>
      ScheduleCompletion.create({
        workoutSchedule: schedule._id,
        user: userId,
        coach: schedule.coach,
        status: 'pending',
      }).catch((err) => {
        if (err.code !== 11000) throw err;
      }),
    ),
  ]);
}

/**
 * When a member leaves a class, drop only still-pending completion rows so
 * completed history is preserved and group percentages stay accurate.
 */
async function clearPendingGroupPlanAccess(userId, classIds) {
  const ids = (Array.isArray(classIds) ? classIds : [classIds])
    .filter(Boolean)
    .map((id) => id._id || id);
  if (!userId || !ids.length) return;

  const [exercisePlans, schedules] = await Promise.all([
    ExercisePlan.find({ fitnessClass: { $in: ids }, status: 'active' }).select('_id').lean(),
    WorkoutSchedule.find({
      fitnessClass: { $in: ids },
      status: { $in: ['scheduled', 'completed'] },
    }).select('_id').lean(),
  ]);

  await Promise.all([
    exercisePlans.length
      ? WorkoutCompletion.deleteMany({
          user: userId,
          status: 'pending',
          exercisePlan: { $in: exercisePlans.map((p) => p._id) },
        })
      : Promise.resolve(),
    schedules.length
      ? ScheduleCompletion.deleteMany({
          user: userId,
          status: 'pending',
          workoutSchedule: { $in: schedules.map((s) => s._id) },
        })
      : Promise.resolve(),
  ]);
}

module.exports = { backfillGroupPlanAccess, clearPendingGroupPlanAccess };
