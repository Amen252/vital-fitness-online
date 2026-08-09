import '../models/diet_plan_model.dart';

/// Status of a scheduled diet meal relative to the user's local clock.
enum DietMealReminderStatus {
  upcoming,
  due,
  completed,
  passed,
}

class DietMealReminderItem {
  final String type;
  final String label;
  final String name;
  final String reminderTime; // HH:mm from DietPlan
  final DateTime scheduledAt;
  final bool completed;
  final DietMealReminderStatus status;

  const DietMealReminderItem({
    required this.type,
    required this.label,
    required this.name,
    required this.reminderTime,
    required this.scheduledAt,
    required this.completed,
    required this.status,
  });

  String get displayName => name.trim().isNotEmpty ? name.trim() : label;

  String get statusLabel => switch (status) {
        DietMealReminderStatus.upcoming => 'Upcoming',
        DietMealReminderStatus.due => 'Due now',
        DietMealReminderStatus.completed => 'Completed',
        DietMealReminderStatus.passed => 'Missed',
      };
}

/// Parses coach-configured `reminderTime` ("HH:mm" / "H:mm") into today's local DateTime.
DateTime? scheduledTimeToday(String reminderTime, [DateTime? now]) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(reminderTime.trim());
  if (match == null) return null;
  final h = int.tryParse(match.group(1)!);
  final m = int.tryParse(match.group(2)!);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
  final n = now ?? DateTime.now();
  return DateTime(n.year, n.month, n.day, h, m);
}

String formatMealClock(String reminderTime) {
  final dt = scheduledTimeToday(reminderTime);
  if (dt == null) return reminderTime;
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final suffix = dt.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}

/// Builds today's meal schedule from the active Diet Plan + adherence.
/// Uses coach `reminderTime` only — no hardcoded meal times.
List<DietMealReminderItem> buildTodayMealReminders({
  required Map<String, dynamic>? planJson,
  required Map<String, dynamic>? todayJson,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  if (planJson == null) return const [];

  final status = planJson['status']?.toString() ?? 'active';
  if (status != 'active') return const [];

  final plan = DietPlan.fromJson(Map<String, dynamic>.from(planJson));
  final meals = _todaysPlanMeals(plan, clock);
  if (meals.isEmpty) return const [];

  final completedTypes = _completedMealTypes(todayJson);
  final scheduled = <DietMealReminderItem>[];

  for (final meal in meals) {
    if (!meal.hasContent) continue;
    // Snacks appear on the diet plan only — never in the reminder schedule.
    final type = meal.type;
    if (type == 'snacks') continue;
    final time = meal.reminderTime.trim();
    final at = scheduledTimeToday(time, clock);
    if (at == null) continue;
    final done = completedTypes.contains(type);
    scheduled.add(
      DietMealReminderItem(
        type: type,
        label: DietMeal.labelForType(type),
        name: meal.name.trim().isNotEmpty ? meal.name.trim() : DietMeal.labelForType(type),
        reminderTime: time,
        scheduledAt: at,
        completed: done,
        status: DietMealReminderStatus.upcoming, // filled below
      ),
    );
  }

  scheduled.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  return [
    for (var i = 0; i < scheduled.length; i++)
      DietMealReminderItem(
        type: scheduled[i].type,
        label: scheduled[i].label,
        name: scheduled[i].name,
        reminderTime: scheduled[i].reminderTime,
        scheduledAt: scheduled[i].scheduledAt,
        completed: scheduled[i].completed,
        status: _statusFor(
          item: scheduled[i],
          nextAt: i + 1 < scheduled.length ? scheduled[i + 1].scheduledAt : null,
          now: clock,
        ),
      ),
  ];
}

/// Next meal to highlight on the User Dashboard.
/// Priority: due → upcoming → null (all done / none scheduled).
DietMealReminderItem? nextMealReminder(List<DietMealReminderItem> items) {
  for (final item in items) {
    if (item.status == DietMealReminderStatus.due) return item;
  }
  for (final item in items) {
    if (item.status == DietMealReminderStatus.upcoming) return item;
  }
  return null;
}

List<DietMeal> _todaysPlanMeals(DietPlan plan, DateTime now) {
  if (plan.todaysMeals.isNotEmpty) {
    return plan.todaysMeals.where((m) => m.hasContent).toList();
  }
  if (plan.isWeekly) {
    return plan.mealsForDay(DietDay.mondayBasedDayOfWeek(now)).where((m) => m.hasContent).toList();
  }
  // Single-day: only on the target weekday.
  if (plan.targetDayOfWeek != null &&
      plan.targetDayOfWeek != DietDay.mondayBasedDayOfWeek(now)) {
    return const [];
  }
  return plan.meals.where((m) => m.hasContent).toList();
}

Set<String> _completedMealTypes(Map<String, dynamic>? todayJson) {
  final done = <String>{};
  if (todayJson == null) return done;

  final summary = todayJson['mealSummary'];
  if (summary is Map && summary['meals'] is List) {
    for (final raw in summary['meals'] as List) {
      if (raw is! Map) continue;
      final type = raw['type']?.toString() ?? '';
      if (type.isEmpty) continue;
      if (raw['completed'] == true || raw['followed'] == true) done.add(type);
    }
  }

  final adherence = todayJson['mealAdherence'];
  if (adherence is List) {
    for (final raw in adherence) {
      if (raw is! Map) continue;
      final type = raw['type']?.toString() ?? '';
      if (type.isEmpty) continue;
      if (raw['completed'] == true || raw['followed'] == true) done.add(type);
    }
  }
  return done;
}

DietMealReminderStatus _statusFor({
  required DietMealReminderItem item,
  required DateTime? nextAt,
  required DateTime now,
}) {
  if (item.completed) return DietMealReminderStatus.completed;
  if (now.isBefore(item.scheduledAt)) return DietMealReminderStatus.upcoming;
  // Due from scheduled time until the next meal starts (or end of day).
  if (nextAt == null || now.isBefore(nextAt)) {
    return DietMealReminderStatus.due;
  }
  return DietMealReminderStatus.passed;
}
