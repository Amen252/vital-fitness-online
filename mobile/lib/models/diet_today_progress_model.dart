class DietTodayProgress {
  final int caloriesConsumed;
  final int targetCalories;
  final int waterMl;
  final int targetWaterMl;
  final int mealsCompleted;
  final int mealsPlanned;
  final int workoutsCompleted;
  final int workoutsPlanned;
  final int dailyGoalPercent;
  final int adherencePercent;
  final bool followedPlan;
  final bool hasActivity;
  final List<Map<String, dynamic>> mealAdherence;
  final int weeklyAveragePercent;

  const DietTodayProgress({
    this.caloriesConsumed = 0,
    this.targetCalories = 0,
    this.waterMl = 0,
    this.targetWaterMl = 2000,
    this.mealsCompleted = 0,
    this.mealsPlanned = 0,
    this.workoutsCompleted = 0,
    this.workoutsPlanned = 0,
    this.dailyGoalPercent = 0,
    this.adherencePercent = 0,
    this.followedPlan = false,
    this.hasActivity = false,
    this.mealAdherence = const [],
    this.weeklyAveragePercent = 0,
  });

  factory DietTodayProgress.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DietTodayProgress();
    return DietTodayProgress(
      caloriesConsumed: (json['caloriesConsumed'] as num?)?.toInt() ?? 0,
      targetCalories: (json['targetCalories'] as num?)?.toInt() ?? 0,
      waterMl: (json['waterMl'] as num?)?.toInt() ?? 0,
      targetWaterMl: (json['targetWaterMl'] as num?)?.toInt() ?? 2000,
      mealsCompleted: (json['mealsCompleted'] as num?)?.toInt() ?? 0,
      mealsPlanned: (json['mealsPlanned'] as num?)?.toInt() ?? 0,
      workoutsCompleted: (json['workoutsCompleted'] as num?)?.toInt() ?? 0,
      workoutsPlanned: (json['workoutsPlanned'] as num?)?.toInt() ?? 0,
      dailyGoalPercent: (json['dailyGoalPercent'] as num?)?.toInt() ?? 0,
      adherencePercent: (json['adherencePercent'] as num?)?.toInt() ?? 0,
      followedPlan: json['followedPlan'] == true,
      hasActivity: json['hasActivity'] == true,
      mealAdherence: (json['mealAdherence'] as List<dynamic>? ?? [])
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList(),
      weeklyAveragePercent: (json['weeklyAveragePercent'] as num?)?.toInt() ?? 0,
    );
  }

  double get caloriesProgress =>
      targetCalories > 0 ? (caloriesConsumed / targetCalories).clamp(0.0, 1.0) : 0.0;

  double get waterProgress => targetWaterMl > 0 ? (waterMl / targetWaterMl).clamp(0.0, 1.0) : 0.0;

  double get mealsProgress =>
      mealsPlanned > 0 ? (mealsCompleted / mealsPlanned).clamp(0.0, 1.0) : 0.0;

  double get workoutsProgress =>
      workoutsPlanned > 0 ? (workoutsCompleted / workoutsPlanned).clamp(0.0, 1.0) : 0.0;

  double get dailyGoalProgress => (dailyGoalPercent / 100).clamp(0.0, 1.0);
}
