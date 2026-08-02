const mongoose = require('mongoose');
const CoachAssignment = require('../models/CoachAssignment');
const CoachClientAssignment = require('../models/CoachClientAssignment');
const CoachRequest = require('../models/CoachRequest');
const FitnessClass = require('../models/FitnessClass');

async function hasActiveAssignment(coachId, userId) {
  const [legacy, modern] = await Promise.all([
    CoachAssignment.findOne({ coach: coachId, user: userId, status: 'active' }).select('_id'),
    CoachClientAssignment.findOne({ coach_id: coachId, user_id: userId, status: 'active' }).select('_id'),
  ]);
  return !!(legacy || modern);
}

async function hasPendingRequest(coachId, userId) {
  const request = await CoachRequest.findOne({
    coach: coachId,
    user: userId,
    status: 'pending',
  }).select('_id');
  return !!request;
}

async function coachCanAccessUser(coachId, userId) {
  const [assigned, pending] = await Promise.all([
    hasActiveAssignment(coachId, userId),
    hasPendingRequest(coachId, userId),
  ]);
  return assigned || pending;
}

async function getActiveClientIds(coachId) {
  const coachObjId = typeof coachId === 'string' ? new mongoose.Types.ObjectId(coachId) : coachId;

  const [legacyAssignments, modernAssignments] = await Promise.all([
    CoachAssignment.find({ coach: coachObjId, status: 'active' }).select('user').lean(),
    CoachClientAssignment.find({ coach_id: coachObjId, status: 'active' }).select('user_id').lean(),
  ]);

  const seen = new Set();
  const ids = [];
  for (const a of legacyAssignments) {
    if (a.user) { const k = String(a.user); if (!seen.has(k)) { seen.add(k); ids.push(a.user); } }
  }
  for (const a of modernAssignments) {
    if (a.user_id) { const k = String(a.user_id); if (!seen.has(k)) { seen.add(k); ids.push(a.user_id); } }
  }
  return ids;
}

/** Coach IDs a user may receive workout schedules from (active assignments + enrolled class coaches). */
async function getAuthorizedCoachIdsForUser(userId) {
  const [assignments, modernAssignments, classes] = await Promise.all([
    CoachAssignment.find({ user: userId, status: 'active' }).select('coach').lean(),
    CoachClientAssignment.find({ user_id: userId, status: 'active' }).select('coach_id').lean(),
    FitnessClass.find({ enrolledStudents: userId }).select('coach').lean(),
  ]);
  const ids = new Set();
  assignments.forEach((a) => { if (a.coach) ids.add(String(a.coach)); });
  modernAssignments.forEach((a) => { if (a.coach_id) ids.add(String(a.coach_id)); });
  classes.forEach((c) => { if (c.coach) ids.add(String(c.coach)); });
  return [...ids].map((id) => new mongoose.Types.ObjectId(id));
}

/**
 * Chat and legacy coach APIs use CoachAssignment. Ensure a row exists when only
 * CoachClientAssignment is active (keeps both collections in sync).
 */
async function ensureLegacyCoachAssignment(coachId, userId) {
  const coachObjId = typeof coachId === 'string' ? new mongoose.Types.ObjectId(coachId) : coachId;
  const userObjId = typeof userId === 'string' ? new mongoose.Types.ObjectId(userId) : userId;

  let assignment = await CoachAssignment.findOne({ coach: coachObjId, user: userObjId });
  if (assignment) {
    if (assignment.status !== 'active') {
      assignment.status = 'active';
      await assignment.save();
    }
    return assignment;
  }

  return CoachAssignment.create({
    coach: coachObjId,
    user: userObjId,
    status: 'active',
  });
}

module.exports = {
  hasActiveAssignment,
  hasPendingRequest,
  coachCanAccessUser,
  getActiveClientIds,
  getAuthorizedCoachIdsForUser,
  ensureLegacyCoachAssignment,
};
