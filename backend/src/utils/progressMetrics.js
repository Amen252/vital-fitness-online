function startOfDay(value) {
  const date = new Date(value);
  date.setHours(0, 0, 0, 0);
  return date;
}

function formatDay(value) {
  const date = new Date(value);
  return date.toISOString().slice(0, 10);
}

function buildSeries(logs, dateKey, valueKey, days = 7) {
  const today = startOfDay(new Date());
  const buckets = new Map();

  for (let index = days - 1; index >= 0; index -= 1) {
    const cursor = new Date(today);
    cursor.setDate(cursor.getDate() - index);
    const key = formatDay(cursor);
    buckets.set(key, 0);
  }

  logs.forEach((item) => {
    const dateValue = item?.[dateKey];
    if (!dateValue) return;
    const key = formatDay(dateValue);
    if (!buckets.has(key)) return;
    const nextValue = Number(item?.[valueKey] || 0);
    buckets.set(key, buckets.get(key) + nextValue);
  });

  // Include both `label` (ISO date string) and `date` (Date) so consumers
  // that key by either field continue to work.
  return Array.from(buckets.entries()).map(([label, value]) => ({
    label,
    date: startOfDay(new Date(`${label}T12:00:00`)),
    value,
  }));
}

function sum(logs, key) {
  return (logs || []).reduce((total, item) => total + Number(item?.[key] || 0), 0);
}

module.exports = { buildSeries, sum, startOfDay, formatDay };
