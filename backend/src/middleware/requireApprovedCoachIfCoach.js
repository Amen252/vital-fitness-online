const requireApprovedCoach = require('./requireApprovedCoach');

/**
 * For shared user/coach routes: enforce approval only when the caller is a coach.
 * Members pass through unchanged.
 */
async function requireApprovedCoachIfCoach(req, res, next) {
  if (!req.user || req.user.role !== 'coach') {
    return next();
  }
  return requireApprovedCoach(req, res, next);
}

module.exports = requireApprovedCoachIfCoach;
