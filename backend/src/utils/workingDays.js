const VALID_WORKING_DAYS = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

function parseWorkingDays(workingDays) {
  if (!Array.isArray(workingDays)) {
    return null;
  }

  const selected = [...new Set(workingDays.filter((day) => VALID_WORKING_DAYS.includes(day)))];
  if (!selected.length) {
    return null;
  }

  return VALID_WORKING_DAYS.filter((day) => selected.includes(day));
}

function validateWorkingDays(workingDays) {
  if (!Array.isArray(workingDays) || workingDays.length === 0) {
    return 'Select at least one working day';
  }

  const parsed = parseWorkingDays(workingDays);
  if (!parsed || !parsed.length) {
    return 'Invalid working days';
  }

  return null;
}

module.exports = {
  VALID_WORKING_DAYS,
  parseWorkingDays,
  validateWorkingDays,
};
