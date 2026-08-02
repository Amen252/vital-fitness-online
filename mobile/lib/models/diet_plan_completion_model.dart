class MealCompletionStatus {
  final String type;
  final String label;
  final bool completed;
  final DateTime? completedAt;

  const MealCompletionStatus({
    required this.type,
    required this.label,
    this.completed = false,
    this.completedAt,
  });

  factory MealCompletionStatus.fromJson(Map<String, dynamic> json) => MealCompletionStatus(
        type: json['type']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        completed: json['completed'] == true,
        completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
      );

  String get statusIcon => completed ? '✓' : '○';
  String get statusText => completed ? '$label Completed' : '$label Not Started';
}

/// UI status for diet progress (day or today meals). Not a backend field.
enum DietProgressUiStatus { notStarted, inProgress, completed }

class DietPlanCompletion {
  final String userId;
  final String userName;
  final String planId;
  final String planName;
  final String assigneeType;
  final String? groupName;
  final bool completed;
  final int progressPercent;
  final int completedMeals;
  final int missedMeals;
  final int mealsPlanned;
  final int weeklyAveragePercent;
  final DateTime? completionDate;
  final List<MealCompletionStatus> meals;

  const DietPlanCompletion({
    required this.userId,
    required this.userName,
    required this.planId,
    required this.planName,
    this.assigneeType = 'user',
    this.groupName,
    this.completed = false,
    this.progressPercent = 0,
    this.completedMeals = 0,
    this.missedMeals = 0,
    this.mealsPlanned = 0,
    this.weeklyAveragePercent = 0,
    this.completionDate,
    this.meals = const [],
    this.planType = 'single_day',
    this.completedDays,
    this.daysPlanned,
    this.weekDays = const [],
  });

  factory DietPlanCompletion.fromJson(Map<String, dynamic> json) => DietPlanCompletion(
        userId: json['userId']?.toString() ?? '',
        userName: json['userName']?.toString() ?? 'User',
        planId: json['planId']?.toString() ?? '',
        planName: json['planName']?.toString() ?? 'Diet Plan',
        assigneeType: json['assigneeType']?.toString() ?? 'user',
        groupName: json['groupName']?.toString(),
        completed: json['completed'] == true || json['status']?.toString() == 'completed',
        progressPercent: (json['progressPercent'] as num?)?.toInt() ?? 0,
        completedMeals: (json['completedMeals'] as num?)?.toInt() ?? 0,
        missedMeals: (json['missedMeals'] as num?)?.toInt() ?? 0,
        mealsPlanned: (json['mealsPlanned'] as num?)?.toInt() ?? 0,
        weeklyAveragePercent: (json['weeklyAveragePercent'] as num?)?.toInt() ?? 0,
        completionDate: DateTime.tryParse(json['completionDate']?.toString() ?? ''),
        meals: (json['meals'] as List<dynamic>? ?? [])
            .map((m) => MealCompletionStatus.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
        planType: json['planType']?.toString() ?? 'single_day',
        completedDays: (json['completedDays'] as num?)?.toInt(),
        daysPlanned: (json['daysPlanned'] as num?)?.toInt(),
        weekDays: (json['weekDays'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((d) => DietWeekDayCompletion.fromJson(Map<String, dynamic>.from(d)))
            .toList(),
      );

  final String planType;
  final int? completedDays;
  final int? daysPlanned;
  final List<DietWeekDayCompletion> weekDays;

  bool get isWeekly => planType == 'weekly';

  /// Today's meal progress for the card status icon (0 → not started, partial → in progress, full → completed).
  DietProgressUiStatus get todayProgressStatus {
    if (completed && !isWeekly) return DietProgressUiStatus.completed;
    if (mealsPlanned <= 0) {
      return completed ? DietProgressUiStatus.completed : DietProgressUiStatus.notStarted;
    }
    if (completedMeals <= 0) return DietProgressUiStatus.notStarted;
    if (completedMeals >= mealsPlanned) return DietProgressUiStatus.completed;
    return DietProgressUiStatus.inProgress;
  }

  /// Overall plan status: full week/plan done, else driven by today's activity.
  DietProgressUiStatus get displayProgressStatus {
    if (completed) return DietProgressUiStatus.completed;
    return todayProgressStatus;
  }

  String get statusLabel {
    if (completed) {
      return isWeekly ? 'All 7 days completed' : 'All meals completed';
    }
    switch (todayProgressStatus) {
      case DietProgressUiStatus.completed:
        return isWeekly ? 'Today completed' : 'Completed';
      case DietProgressUiStatus.inProgress:
        return 'In Progress';
      case DietProgressUiStatus.notStarted:
        return 'Not Started';
    }
  }

  String get statusIcon {
    switch (displayProgressStatus) {
      case DietProgressUiStatus.completed:
        return '✓';
      case DietProgressUiStatus.inProgress:
        return '…';
      case DietProgressUiStatus.notStarted:
        return '○';
    }
  }

  String get dailyProgressLabel {
    if (isWeekly && daysPlanned != null) {
      final done = completedDays ?? 0;
      final planned = daysPlanned ?? 7;
      return '$done/$planned Days Completed ($progressPercent%)';
    }
    return mealsPlanned > 0
        ? '$completedMeals/$mealsPlanned Meals Completed ($progressPercent%)'
        : 'No meals planned';
  }

  String get todayMealProgressLabel {
    if (mealsPlanned <= 0) return 'No meals planned today';
    final remaining = (mealsPlanned - completedMeals).clamp(0, mealsPlanned);
    final pct = mealsPlanned > 0 ? ((completedMeals / mealsPlanned) * 100).round() : 0;
    return '$completedMeals/$mealsPlanned meals completed · $remaining remaining · $pct%';
  }
}

class DietWeekDayCompletion {
  final int dayOfWeek;
  final String dayName;
  final bool dayCompleted;
  final List<MealCompletionStatus> meals;

  const DietWeekDayCompletion({
    required this.dayOfWeek,
    required this.dayName,
    this.dayCompleted = false,
    this.meals = const [],
  });

  factory DietWeekDayCompletion.fromJson(Map<String, dynamic> json) {
    const labels = {
      'breakfast': 'Breakfast',
      'lunch': 'Lunch',
      'dinner': 'Dinner',
      'snacks': 'Snacks',
    };
    final adherence = (json['mealAdherence'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m));
    final meals = adherence.map((m) {
      final type = m['type']?.toString() ?? '';
      final completed = m['followed'] == true || m['completed'] == true;
      return MealCompletionStatus(
        type: type,
        label: labels[type] ?? type,
        completed: completed,
        completedAt: DateTime.tryParse(m['completedAt']?.toString() ?? ''),
      );
    }).toList();
    return DietWeekDayCompletion(
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 0,
      dayName: json['dayName']?.toString() ?? '',
      dayCompleted: json['completed'] == true,
      meals: meals,
    );
  }

  int get mealsCompleted => meals.where((m) => m.completed).length;
  int get mealsPlanned => meals.length;

  /// UI: day is complete when marked complete or every planned meal is checked.
  bool get allMealsCompleted =>
      dayCompleted || (mealsPlanned > 0 && mealsCompleted == mealsPlanned);

  DietProgressUiStatus get dayProgressStatus {
    if (allMealsCompleted) return DietProgressUiStatus.completed;
    if (mealsCompleted > 0) return DietProgressUiStatus.inProgress;
    return DietProgressUiStatus.notStarted;
  }

  String get statusIcon {
    switch (dayProgressStatus) {
      case DietProgressUiStatus.completed:
        return '✓';
      case DietProgressUiStatus.inProgress:
        return '…';
      case DietProgressUiStatus.notStarted:
        return '○';
    }
  }

  String dayStatusLabel({required int done, required int planned}) {
    switch (dayProgressStatus) {
      case DietProgressUiStatus.completed:
        return '$dayName completed · $done/$planned meals';
      case DietProgressUiStatus.inProgress:
        return '$dayName in progress · $done/$planned meals';
      case DietProgressUiStatus.notStarted:
        return '$dayName not started · $done/$planned meals';
    }
  }
}
