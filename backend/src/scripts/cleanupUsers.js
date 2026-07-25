/**
 * Remove all coaches and users. Admin accounts are preserved.
 *
 * Usage: node src/scripts/cleanupUsers.js
 */
require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });

const mongoose = require('mongoose');
const User = require('../models/User');
const Profile = require('../models/Profile');
const CoachAssignment = require('../models/CoachAssignment');
const CoachRequest = require('../models/CoachRequest');
const CoachApplication = require('../models/CoachApplication');
const Notification = require('../models/Notification');
const Message = require('../models/Message');
const Session = require('../models/Session');
const FitnessClass = require('../models/FitnessClass');
const DietPlan = require('../models/DietPlan');
const DietAdherence = require('../models/DietAdherence');
const ExercisePlan = require('../models/ExercisePlan');
const Schedule = require('../models/Schedule');
const ActivityLog = require('../models/ActivityLog');
const WaterLog = require('../models/WaterLog');
const MealLog = require('../models/MealLog');

async function cleanup() {
  await mongoose.connect(process.env.MONGO_URI);
  console.log('Connected to MongoDB\n');

  const allUsers = await User.find().lean();
  const keepUsers = allUsers.filter((u) => u.role === 'admin');
  const removeUsers = allUsers.filter((u) => u.role !== 'admin');

  const keepIds = keepUsers.map((u) => u._id);
  const removeIds = removeUsers.map((u) => u._id);

  console.log('Keeping:');
  keepUsers.forEach((u) => console.log(`  [${u.role}] ${u.email} (${u.name})`));

  console.log('\nRemoving:');
  if (removeUsers.length === 0) {
    console.log('  (none)');
  } else {
    removeUsers.forEach((u) => console.log(`  [${u.role}] ${u.email} (${u.name})`));
  }

  if (removeIds.length === 0) {
    console.log('\nNothing to delete.');
    await mongoose.disconnect();
    return;
  }

  const idFilter = { $in: removeIds };

  const results = await Promise.all([
    CoachAssignment.deleteMany({ $or: [{ user: idFilter }, { coach: idFilter }] }),
    CoachRequest.deleteMany({ $or: [{ user: idFilter }, { coach: idFilter }] }),
    CoachApplication.deleteMany({ user: idFilter }),
    Notification.deleteMany({ user: idFilter }),
    Message.deleteMany({ $or: [{ sender: idFilter }, { receiver: idFilter }] }),
    Session.deleteMany({ $or: [{ client: idFilter }, { coach: idFilter }] }),
    FitnessClass.deleteMany({ coach: idFilter }),
    DietPlan.deleteMany({ $or: [{ client: idFilter }, { coach: idFilter }] }),
    DietAdherence.deleteMany({ $or: [{ user: idFilter }, { coach: idFilter }] }),
    ExercisePlan.deleteMany({ $or: [{ client: idFilter }, { coach: idFilter }] }),
    Schedule.deleteMany({ $or: [{ client: idFilter }, { coach: idFilter }] }),
    ActivityLog.deleteMany({ user: idFilter }),
    WaterLog.deleteMany({ user: idFilter }),
    MealLog.deleteMany({ user: idFilter }),
  ]);

  await FitnessClass.updateMany(
    { enrolledStudents: { $in: removeIds } },
    { $pull: { enrolledStudents: { $in: removeIds } } }
  );
  await FitnessClass.updateMany(
    { 'attendance.student': { $in: removeIds } },
    { $pull: { attendance: { student: { $in: removeIds } } } }
  );

  const removedProfiles = removeUsers.map((u) => u.profile).filter(Boolean);
  const keepProfileIds = keepUsers.map((u) => u.profile).filter(Boolean);
  const removedProfileIds = removedProfiles.filter(
    (id) => !keepProfileIds.some((keepId) => String(keepId) === String(id))
  );

  const deletedUsers = await User.deleteMany({ _id: idFilter });

  if (removedProfileIds.length) {
    await Profile.deleteMany({ _id: { $in: removedProfileIds } });
  }

  console.log('\nCleanup summary:');
  console.log(`  Users deleted: ${deletedUsers.deletedCount}`);
  console.log(`  Coach assignments removed: ${results[0].deletedCount}`);
  console.log(`  Coach requests removed: ${results[1].deletedCount}`);
  console.log(`  Messages removed: ${results[5].deletedCount}`);
  console.log(`  Sessions removed: ${results[6].deletedCount}`);
  console.log(`  Classes removed: ${results[7].deletedCount}`);

  const remaining = await User.find({}, 'name email role').sort({ role: 1, email: 1 }).lean();
  console.log('\nRemaining accounts:');
  remaining.forEach((u) => console.log(`  [${u.role}] ${u.email} (${u.name})`));

  await mongoose.disconnect();
}

cleanup().catch((err) => {
  console.error('Cleanup failed:', err);
  process.exit(1);
});
