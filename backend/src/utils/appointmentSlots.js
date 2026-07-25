// Appointment slot helpers. Coaches configure their Working Hours (start/end)
// and appointment duration during registration; these values drive the slots
// that members can book. Sensible defaults are used when a coach has none set.
const DEFAULT_WORK_START = '09:00';
const DEFAULT_WORK_END = '17:00';
const DEFAULT_DURATION = 60;
const ALLOWED_DURATIONS = [30, 45, 60];

// JS Date.getDay(): 0 = Sunday ... 6 = Saturday. Matches the existing Working
// Days feature's day names.
const DAY_NAMES = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

function getDayName(date) {
  return DAY_NAMES[new Date(date).getDay()];
}

// Day-of-week from a calendar date string (timezone-safe).
function getDayNameFromDateStr(dateStr) {
  const dateMatch = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(dateStr || '').trim());
  if (!dateMatch) return '';
  const y = Number(dateMatch[1]);
  const mo = Number(dateMatch[2]);
  const d = Number(dateMatch[3]);
  return DAY_NAMES[new Date(Date.UTC(y, mo - 1, d, 12, 0, 0)).getUTCDay()];
}

function parseTimezoneOffsetMinutes(value) {
  const offset = Number(value);
  return Number.isFinite(offset) ? offset : null;
}

// Wall-clock date/time in the client's timezone -> Date instant.
function parseSlotDateTimeInOffset(dateStr, timeStr, timezoneOffsetMinutes = 0) {
  const dateMatch = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(dateStr || '').trim());
  const timeMatch = /^(\d{1,2}):(\d{2})$/.exec(String(timeStr || '').trim());
  if (!dateMatch || !timeMatch) return null;

  const y = Number(dateMatch[1]);
  const mo = Number(dateMatch[2]);
  const d = Number(dateMatch[3]);
  const h = Number(timeMatch[1]);
  const mi = Number(timeMatch[2]);
  const offset = parseTimezoneOffsetMinutes(timezoneOffsetMinutes) ?? 0;
  const utcMs = Date.UTC(y, mo - 1, d, h, mi) - offset * 60 * 1000;
  const date = new Date(utcMs);
  if (Number.isNaN(date.getTime())) return null;
  return date;
}

function wallClockHHMM(date, timezoneOffsetMinutes = 0) {
  const offset = parseTimezoneOffsetMinutes(timezoneOffsetMinutes) ?? 0;
  const shifted = new Date(date.getTime() + offset * 60 * 1000);
  return `${pad2(shifted.getUTCHours())}:${pad2(shifted.getUTCMinutes())}`;
}

function pad2(n) {
  return String(n).padStart(2, '0');
}

// "HH:mm" -> minutes since midnight, or null when malformed.
function hhmmToMinutes(value) {
  const m = /^(\d{1,2}):(\d{2})$/.exec(String(value || '').trim());
  if (!m) return null;
  const h = Number(m[1]);
  const min = Number(m[2]);
  if (h < 0 || h > 23 || min < 0 || min > 59) return null;
  return h * 60 + min;
}

function minutesToHHMM(total) {
  return `${pad2(Math.floor(total / 60))}:${pad2(total % 60)}`;
}

function isValidHHMM(value) {
  return hhmmToMinutes(value) !== null;
}

function sanitizeDuration(duration) {
  const d = Number(duration);
  return ALLOWED_DURATIONS.includes(d) ? d : DEFAULT_DURATION;
}

// Generates slot start times ("HH:mm") between start and end, stepping by the
// duration and only including slots that fully fit before the end time.
function generateSlotTimes(start = DEFAULT_WORK_START, end = DEFAULT_WORK_END, duration = DEFAULT_DURATION) {
  const startM = hhmmToMinutes(start) ?? hhmmToMinutes(DEFAULT_WORK_START);
  const endM = hhmmToMinutes(end) ?? hhmmToMinutes(DEFAULT_WORK_END);
  const step = sanitizeDuration(duration);
  const slots = [];
  for (let m = startM; m + step <= endM; m += step) {
    slots.push(minutesToHHMM(m));
  }
  return slots;
}

function isValidSlotTime(time, start, end, duration) {
  return generateSlotTimes(start, end, duration).includes(String(time || '').trim());
}

// Parses "YYYY-MM-DD" + "HH:mm" into a Date in the server's local timezone.
function parseSlotDateTime(dateStr, timeStr) {
  const dateMatch = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(dateStr || '').trim());
  const timeMatch = /^(\d{1,2}):(\d{2})$/.exec(String(timeStr || '').trim());
  if (!dateMatch || !timeMatch) return null;

  const [, y, mo, d] = dateMatch;
  const [, h, mi] = timeMatch;
  const date = new Date(Number(y), Number(mo) - 1, Number(d), Number(h), Number(mi), 0, 0);
  if (Number.isNaN(date.getTime())) return null;
  return date;
}

// Validates + normalizes the working-hours settings coming from a request.
// Returns { value: { start, end, durationMinutes } } or { error }.
function normalizeWorkingHours({ start, end, durationMinutes } = {}) {
  let startM = hhmmToMinutes(start);
  let endM = hhmmToMinutes(end);

  if (start !== undefined && start !== null && start !== '' && startM === null) {
    return { error: 'Invalid working hours start time' };
  }
  if (end !== undefined && end !== null && end !== '' && endM === null) {
    return { error: 'Invalid working hours end time' };
  }

  startM = startM ?? hhmmToMinutes(DEFAULT_WORK_START);
  endM = endM ?? hhmmToMinutes(DEFAULT_WORK_END);

  if (endM <= startM) {
    return { error: 'Working hours end time must be after the start time' };
  }

  const dur = sanitizeDuration(durationMinutes);
  if (endM - startM < dur) {
    return { error: 'Working hours must be at least one appointment slot long' };
  }

  return {
    value: { start: minutesToHHMM(startM), end: minutesToHHMM(endM), durationMinutes: dur },
  };
}

// Validates per-day availability for each selected appointment day.
// Returns { value: [{ day, start, end }], durationMinutes } or { error }.
function normalizeDayAvailability(appointmentDays, dayAvailability, durationMinutes = DEFAULT_DURATION) {
  const { parseWorkingDays } = require('./workingDays');
  const parsedDays = parseWorkingDays(appointmentDays);
  if (!parsedDays || !parsedDays.length) {
    return { error: 'Select at least one appointment day' };
  }
  if (!Array.isArray(dayAvailability) || !dayAvailability.length) {
    return { error: 'Configure availability for each appointment day' };
  }

  const dur = sanitizeDuration(durationMinutes);
  const normalized = [];

  for (const day of parsedDays) {
    const entry = dayAvailability.find((item) => item?.day === day);
    if (!entry) {
      return { error: `Set working hours for ${day}` };
    }
    const hours = normalizeWorkingHours({ start: entry.start, end: entry.end, durationMinutes: dur });
    if (hours.error) {
      return { error: `${day}: ${hours.error}` };
    }
    normalized.push({ day, start: hours.value.start, end: hours.value.end });
  }

  return { value: normalized, durationMinutes: dur };
}

function getHoursForDay(dayAvailability, dayName, fallbackStart, fallbackEnd) {
  if (Array.isArray(dayAvailability)) {
    const entry = dayAvailability.find((item) => item?.day === dayName);
    if (entry?.start && entry?.end) {
      return { start: entry.start, end: entry.end };
    }
  }
  return {
    start: fallbackStart || DEFAULT_WORK_START,
    end: fallbackEnd || DEFAULT_WORK_END,
  };
}

module.exports = {
  DEFAULT_WORK_START,
  DEFAULT_WORK_END,
  DEFAULT_DURATION,
  ALLOWED_DURATIONS,
  DAY_NAMES,
  getDayName,
  getDayNameFromDateStr,
  parseTimezoneOffsetMinutes,
  parseSlotDateTimeInOffset,
  wallClockHHMM,
  hhmmToMinutes,
  minutesToHHMM,
  isValidHHMM,
  sanitizeDuration,
  generateSlotTimes,
  isValidSlotTime,
  parseSlotDateTime,
  normalizeWorkingHours,
  normalizeDayAvailability,
  getHoursForDay,
};
