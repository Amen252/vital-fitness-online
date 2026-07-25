const CoachApplication = require('../models/CoachApplication');

async function getNonApprovedCoachApplicantIds() {
  return CoachApplication.distinct('user', {
    status: { $in: ['pending', 'rejected'] },
  });
}

/**
 * Mongo filter for gym members shown in Admin → Users.
 * Excludes coaches and pending/rejected coach applicants (those live under Coaches → Applications).
 */
async function buildMemberUserFilter(extra = {}) {
  const hiddenApplicantIds = await getNonApprovedCoachApplicantIds();
  const filter = {
    role: 'user',
    status: { $ne: 'deleted' },
    ...extra,
  };
  if (hiddenApplicantIds.length) {
    filter._id = { $nin: hiddenApplicantIds };
  }
  return filter;
}

module.exports = {
  getNonApprovedCoachApplicantIds,
  getPendingCoachApplicantIds: async () =>
    CoachApplication.distinct('user', { status: 'pending' }),
  buildMemberUserFilter,
};
