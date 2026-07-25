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

  String get statusIcon => completed ? '✅' : '❌';
  String get statusText => completed ? '$label completed' : '$label not completed';
}

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
      );

  String get statusLabel => completed ? 'All meals completed' : 'In progress';

  String get statusIcon => completed ? '✅' : '⏳';

  String get dailyProgressLabel =>
      mealsPlanned > 0 ? '$completedMeals/$mealsPlanned Meals Completed ($progressPercent%)' : 'No meals planned';
}
