const mongoose = require('mongoose');
const CoachClientAssignment = require('../models/CoachClientAssignment');
const Appointment = require('../models/Appointment');
const WorkoutPlan = require('../models/WorkoutPlan');

/**
 * Row-level ownership authorization middleware.
 * Enforces:
 * - Admin has full access.
 * - Coach has access to own schedule/clients only.
 * - User has access to own data/coach schedule booking only.
 */
const authorize = (resourceType, action) => {
  return async (req, res, next) => {
    try {
      const actor = req.user;
      if (!actor) {
        return res.status(401).json({ message: 'Authentication required' });
      }

      // Admin has bypass for most things
      if (actor.role === 'admin') {
        // Enforce restriction: Admin cannot write DailyTracking / WorkoutLog directly (view aggregate only)
        if (resourceType === 'daily_tracking' || resourceType === 'workout_log') {
          if (action === 'create' || action === 'update' || action === 'delete') {
            return res.status(403).json({ message: 'Admins cannot modify daily tracking or workout logs directly.' });
          }
        }
        return next();
      }

      const resourceId = req.params.id;

      // 1. User profiles & data access
      if (resourceType === 'user_profile') {
        const targetId = resourceId || req.body.user_id || req.body.id;
        if (String(actor._id) === String(targetId)) {
          return next(); // Own account
        }

        if (actor.role === 'coach') {
          // Coach can access only assigned clients
          const isAssigned = await CoachClientAssignment.findOne({
            coach_id: actor._id,
            user_id: targetId,
            status: 'active',
          });
          if (isAssigned) return next();
        }

        return res.status(403).json({ message: 'Access denied: not authorized for this user profile' });
      }

      // 2. Diet plans
      if (resourceType === 'diet_plan') {
        if (action === 'create') {
          const targetId = req.body.assigned_to || req.body.client;
          if (actor.role === 'coach') {
            const isAssigned = await CoachClientAssignment.findOne({
              coach_id: actor._id,
              user_id: targetId,
              status: 'active',
            });
            if (isAssigned) return next();
          }
          return res.status(403).json({ message: 'Access denied: cannot assign plan to this client' });
        }

        // For read/update/delete, fetch resource
        if (resourceId) {
          const plan = await mongoose.model('DietPlan').findById(resourceId);
          if (!plan) return res.status(404).json({ message: 'Diet plan not found' });

          const clientUserId = plan.client || plan.assigned_to;
          if (actor.role === 'user' && String(clientUserId) === String(actor._id) && action === 'read') {
            return next();
          }

          if (actor.role === 'coach' && String(plan.coach || plan.created_by) === String(actor._id)) {
            return next();
          }
        }
        return res.status(403).json({ message: 'Access denied: unauthorized for this diet plan' });
      }

      // 3. Workout plans
      if (resourceType === 'workout_plan') {
        if (action === 'create') {
          const targetId = req.body.assigned_to || req.body.client;
          if (actor.role === 'coach') {
            const isAssigned = await CoachClientAssignment.findOne({
              coach_id: actor._id,
              user_id: targetId,
              status: 'active',
            });
            if (isAssigned) return next();
          }
          return res.status(403).json({ message: 'Access denied: cannot assign workout plan to this client' });
        }

        if (resourceId) {
          const plan = await WorkoutPlan.findById(resourceId);
          if (!plan) return res.status(404).json({ message: 'Workout plan not found' });

          if (actor.role === 'user' && String(plan.assigned_to) === String(actor._id) && action === 'read') {
            return next();
          }

          if (actor.role === 'coach' && String(plan.created_by) === String(actor._id)) {
            return next();
          }
        }
        return res.status(403).json({ message: 'Access denied: unauthorized for this workout plan' });
      }

      // 4. Appointments
      if (resourceType === 'appointment') {
        if (action === 'create') {
          return next();
        }

        if (resourceId) {
          const appointment = await Appointment.findById(resourceId);
          if (!appointment) return res.status(404).json({ message: 'Appointment not found' });

          if (actor.role === 'user' && String(appointment.user_id) === String(actor._id)) {
            return next();
          }
          if (actor.role === 'coach' && String(appointment.coach_id) === String(actor._id)) {
            return next();
          }
        }
        return res.status(403).json({ message: 'Access denied: unauthorized for this appointment' });
      }

      // 5. Daily tracking
      if (resourceType === 'daily_tracking') {
        if (actor.role === 'user') {
          const targetId = req.body.user_id || req.query.user_id;
          if (!targetId || String(actor._id) === String(targetId)) return next();
        } else if (actor.role === 'coach' && action === 'read') {
          const targetId = req.query.user_id;
          const isAssigned = await CoachClientAssignment.findOne({
            coach_id: actor._id,
            user_id: targetId,
            status: 'active',
          });
          if (isAssigned) return next();
        }
        return res.status(403).json({ message: 'Access denied: unauthorized daily tracking action' });
      }

      // 6. Workout logs
      if (resourceType === 'workout_log') {
        if (actor.role === 'user') {
          const targetId = req.body.user_id || req.query.user_id;
          if (!targetId || String(actor._id) === String(targetId)) return next();
        } else if (actor.role === 'coach' && action === 'read') {
          const targetId = req.query.user_id;
          const isAssigned = await CoachClientAssignment.findOne({
            coach_id: actor._id,
            user_id: targetId,
            status: 'active',
          });
          if (isAssigned) return next();
        }
        return res.status(403).json({ message: 'Access denied: unauthorized workout log action' });
      }

      return res.status(403).json({ message: 'Access denied' });
    } catch (err) {
      console.error('[AUTH] Authorization middleware error:', err);
      return res.status(500).json({ message: 'Internal authorization error' });
    }
  };
};

module.exports = authorize;
