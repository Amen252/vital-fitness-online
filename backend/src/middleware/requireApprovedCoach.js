const CoachApplication = require('../models/CoachApplication');

/**
 * Blocks coach-role accounts that are not fully approved from coach APIs.
 * Pending / rejected applicants must not use coach features.
 */
async function requireApprovedCoach(req, res, next) {
  try {
    if (!req.user || req.user.role !== 'coach') {
      return res.status(403).json({ message: 'You do not have access to this resource' });
    }

    const approval = req.user.coachData?.approval_status;
    if (approval === 'approved') {
      return next();
    }

    const application = await CoachApplication.findOne({ user: req.user._id })
      .select('status')
      .lean();

    // Admin-created coaches may have no application and no approval_status.
    if (!application && approval !== 'pending' && approval !== 'rejected') {
      return next();
    }

    const status = application?.status || approval;
    if (status === 'approved') {
      return next();
    }
    if (status === 'pending') {
      return res.status(403).json({
        message: 'Your coach application is still pending admin approval.',
        code: 'COACH_PENDING',
      });
    }
    if (status === 'rejected') {
      return res.status(403).json({
        message: 'Your coach application was rejected. Coach features are unavailable.',
        code: 'COACH_REJECTED',
      });
    }

    // Deny unknown / missing approval instead of fail-open.
    return res.status(403).json({
      message: 'Coach approval required before using coach features.',
      code: 'COACH_NOT_APPROVED',
    });
  } catch (error) {
    console.error('[AUTH] requireApprovedCoach:', error.message);
    return res.status(500).json({ message: 'Unable to verify coach approval' });
  }
}

module.exports = requireApprovedCoach;
