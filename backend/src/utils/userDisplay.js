/** Fields to populate when returning a user for display in lists. */
const USER_DISPLAY_SELECT = 'full_name username phone avatar status role';

/** Attach a stable `name`, identity and photo field for users stored as full_name/username/avatar. */
function withDisplayName(user) {
  if (!user || typeof user !== 'object') return user;
  const obj = typeof user.toObject === 'function' ? user.toObject() : { ...user };
  const photo = obj.avatar || obj.photoUrl || obj.profile?.photoUrl || '';
  return {
    ...obj,
    name: obj.full_name || obj.name || obj.username || '',
    email: obj.email || obj.username || '',
    avatar: photo,
    photoUrl: photo,
  };
}

function normalizeEnrolledStudents(students = []) {
  return students.map(withDisplayName);
}

module.exports = {
  USER_DISPLAY_SELECT,
  withDisplayName,
  normalizeEnrolledStudents,
};
