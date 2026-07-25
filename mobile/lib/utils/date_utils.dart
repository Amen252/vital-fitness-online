// Shared date helpers for API fields — avoids timezone day shifts.

import 'package:flutter/material.dart';

/// Parse YYYY-MM-DD or ISO date-only fields (e.g. weekStartDate).
DateTime? parseApiDateOnly(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final datePart = raw.contains('T') ? raw.split('T').first : raw.trim();
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datePart)) {
    final parts = datePart.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  final utc = parsed.toUtc();
  return DateTime(utc.year, utc.month, utc.day);
}

/// Calendar date for a day index within a week starting on [weekStart] (Monday).
DateTime weekDayDate(DateTime weekStart, int dayIndex) {
  final start = dateOnly(weekStart);
  return dateOnly(start.add(Duration(days: dayIndex)));
}

DateTime mondayOf(DateTime d) {
  final diff = d.weekday - DateTime.monday;
  return DateTime(d.year, d.month, d.day - diff);
}

/// Strip time — use for date pickers and comparisons.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Default week for a new plan: current week's Monday, or next Monday on Sat/Sun.
DateTime defaultWeekStartForNewPlan() {
  final today = dateOnly(DateTime.now());
  if (today.weekday >= DateTime.saturday) {
    final daysToAdd = (DateTime.monday - today.weekday + 7) % 7;
    return today.add(Duration(days: daysToAdd == 0 ? 7 : daysToAdd));
  }
  return mondayOf(today);
}

String formatWeekRange(DateTime weekStart) {
  final start = dateOnly(weekStart);
  final end = start.add(const Duration(days: 6));
  const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  if (start.month == end.month) {
    return '${months[start.month]} ${start.day} – ${end.day}, ${start.year}';
  }
  return '${months[start.month]} ${start.day} – ${months[end.month]} ${end.day}, ${end.year}';
}

String formatDateOnly(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String formatDisplayDate(DateTime d) => '${d.month}/${d.day}/${d.year}';

/// Parse API datetime for display in device local time.
DateTime? parseApiDateTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.parse(raw).toLocal();
}

String formatApiDateTime(String? raw) {
  final dt = parseApiDateTime(raw);
  if (dt == null) return 'Scheduled';
  const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final suffix = dt.hour < 12 ? 'AM' : 'PM';
  return '${months[dt.month]} ${dt.day}, ${dt.year} · $h:$m $suffix';
}

String formatApiTime(String? raw) {
  final dt = parseApiDateTime(raw);
  if (dt == null) return '';
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final suffix = dt.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $suffix';
}

String formatScheduleRange(String? startRaw, String? endRaw) {
  final start = parseApiDateTime(startRaw);
  if (start == null) return 'TBD';
  String fmt(DateTime d) => '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  final end = parseApiDateTime(endRaw);
  return end != null ? '${fmt(start)} – ${fmt(end)}' : fmt(start);
}

/// Serialize local picker datetime for API (UTC ISO).
String toApiDateTime(DateTime local) => local.toUtc().toIso8601String();

DateTime combineDateAndTime(DateTime date, TimeOfDay time) =>
    DateTime(date.year, date.month, date.day, time.hour, time.minute);

bool isFutureAppointmentSlot(DateTime date, TimeOfDay time) {
  final dt = combineDateAndTime(date, time);
  return dt.isAfter(DateTime.now().add(const Duration(minutes: 1)));
}

DateTime defaultAppointmentDate() {
  final now = DateTime.now();
  return dateOnly(now).add(const Duration(days: 1));
}

/// 10:00 for future days; next 30-minute slot when scheduling for today.
TimeOfDay defaultAppointmentTimeFor(DateTime date) {
  final now = DateTime.now();
  if (dateOnly(date).isAfter(dateOnly(now))) {
    return const TimeOfDay(hour: 10, minute: 0);
  }

  var candidate = DateTime(now.year, now.month, now.day, now.hour, now.minute)
      .add(const Duration(minutes: 30));
  var hour = candidate.hour;
  var minute = ((candidate.minute + 14) ~/ 15) * 15;
  if (minute >= 60) {
    hour += 1;
    minute = 0;
  }
  if (hour >= 23) return const TimeOfDay(hour: 23, minute: 0);
  return TimeOfDay(hour: hour, minute: minute);
}

TimeOfDay ensureFutureTimeForDate(DateTime date, TimeOfDay time) {
  if (isFutureAppointmentSlot(date, time)) return time;
  return defaultAppointmentTimeFor(date);
}
