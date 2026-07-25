const DAY_NAMES = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

function parseLocalDate(dateInput) {
  if (typeof dateInput === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(dateInput)) {
    const [year, month, day] = dateInput.split('-').map(Number);
    return new Date(year, month - 1, day);
  }
  const d = dateInput instanceof Date ? dateInput : new Date(dateInput);
  if (Number.isNaN(d.getTime())) return new Date();
  // Use UTC date parts so noon-UTC storage maps to the intended calendar day.
  return new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
}

function toDateOnlyStorage(d) {
  const local = parseLocalDate(d);
  return new Date(Date.UTC(local.getFullYear(), local.getMonth(), local.getDate(), 12, 0, 0));
}

function getWeekStart(dateInput) {
  const d = parseLocalDate(dateInput);
  const day = d.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  d.setDate(d.getDate() + diff);
  return toDateOnlyStorage(d);
}

function combineDateAndTime(weekStart, dayOfWeek, timeStr, timezoneOffsetMinutes = 0) {
  const base = parseLocalDate(weekStart);
  const year = base.getFullYear();
  const month = base.getMonth();
  const day = base.getDate() + dayOfWeek;
  const parts = String(timeStr || '09:00').split(':');
  const hours = parseInt(parts[0], 10) || 9;
  const minutes = parseInt(parts[1], 10) || 0;
  // Coach wall-clock time → UTC instant using device offset from Flutter.
  const utcMs = Date.UTC(year, month, day, hours, minutes, 0, 0) - timezoneOffsetMinutes * 60000;
  return new Date(utcMs);
}

function formatDateOnlyIso(dateInput) {
  const d = parseLocalDate(dateInput);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/** Calendar date in a wall-clock timezone (Flutter [timeZoneOffset.inMinutes]). */
function calendarDateFromInstant(instant, timezoneOffsetMinutes = 0) {
  const d = instant instanceof Date ? instant : new Date(instant);
  if (Number.isNaN(d.getTime())) return parseLocalDate(new Date());
  const shifted = new Date(d.getTime() + timezoneOffsetMinutes * 60000);
  return new Date(shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate());
}

function isSameCalendarDay(a, b) {
  return a.getFullYear() === b.getFullYear()
    && a.getMonth() === b.getMonth()
    && a.getDate() === b.getDate();
}

function defaultWeekDays() {
  return DAY_NAMES.map((_, i) => ({
    dayOfWeek: i,
    enabled: false,
    offDay: false,
    startTime: '09:00',
    endTime: '10:00',
    notes: '',
  }));
}

module.exports = {
  DAY_NAMES,
  getWeekStart,
  combineDateAndTime,
  defaultWeekDays,
  parseLocalDate,
  toDateOnlyStorage,
  formatDateOnlyIso,
  calendarDateFromInstant,
  isSameCalendarDay,
};
