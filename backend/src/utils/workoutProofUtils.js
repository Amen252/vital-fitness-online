const PROOF_PHOTO_RE = /^data:image\/(png|jpe?g|webp|gif);base64,/;

/**
 * Validate workout completion proof payload.
 * @returns {{ ok: true, notes: string, durationMinutes: number, proofPhoto: string } | { ok: false, message: string }}
 */
function validateWorkoutProof(body = {}) {
  const notes = String(body.notes || '').trim();
  const proofPhoto = String(body.proofPhoto || '').trim();
  const durationRaw = body.durationMinutes;
  const durationMinutes = typeof durationRaw === 'number'
    ? durationRaw
    : parseInt(String(durationRaw ?? ''), 10);

  if (!notes) {
    return { ok: false, message: 'Workout notes are required' };
  }
  if (!Number.isFinite(durationMinutes) || durationMinutes < 1) {
    return { ok: false, message: 'Workout duration (minutes) is required' };
  }
  if (durationMinutes > 24 * 60) {
    return { ok: false, message: 'Duration looks invalid' };
  }
  if (!proofPhoto || !PROOF_PHOTO_RE.test(proofPhoto)) {
    return { ok: false, message: 'A workout photo is required (PNG, JPEG, WebP, or GIF)' };
  }

  return { ok: true, notes, durationMinutes, proofPhoto };
}

function dayKey(date) {
  const d = new Date(date);
  if (Number.isNaN(d.getTime())) return null;
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/**
 * Consecutive calendar days with ≥1 completed workout, ending today or yesterday.
 */
function computeWorkoutStreak(completedDates) {
  const days = new Set();
  for (const raw of completedDates) {
    const key = dayKey(raw);
    if (key) days.add(key);
  }
  if (days.size === 0) return 0;

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const todayKey = dayKey(today);
  const yesterday = new Date(today);
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayKey = dayKey(yesterday);

  let cursor = days.has(todayKey) ? today : (days.has(yesterdayKey) ? yesterday : null);
  if (!cursor) return 0;

  let streak = 0;
  while (days.has(dayKey(cursor))) {
    streak += 1;
    cursor = new Date(cursor);
    cursor.setDate(cursor.getDate() - 1);
  }
  return streak;
}

module.exports = {
  validateWorkoutProof,
  computeWorkoutStreak,
  dayKey,
};
