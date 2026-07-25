class DietMeal {
  final String? id;
  final String type;
  final String name;
  final String description;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  final String reminderTime;

  const DietMeal({
    this.id,
    required this.type,
    this.name = '',
    this.description = '',
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fats = 0,
    this.reminderTime = '',
  });

  factory DietMeal.fromJson(Map<String, dynamic> json) => DietMeal(
        id: json['_id']?.toString(),
        type: json['type']?.toString() ?? 'snacks',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        protein: (json['protein'] as num?)?.toInt() ?? 0,
        carbs: (json['carbs'] as num?)?.toInt() ?? 0,
        fats: (json['fats'] as num?)?.toInt() ?? 0,
        reminderTime: json['reminderTime']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'name': name,
        'description': description,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fats': fats,
        'reminderTime': reminderTime,
      };

  bool get hasContent => name.trim().isNotEmpty || description.trim().isNotEmpty;

  static DietMeal empty(String type) => DietMeal(type: type, name: labelForType(type));

  static String labelForType(String type) {
    switch (type) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      default:
        return 'Snacks';
    }
  }
}

class DietDay {
  final int dayOfWeek; // 0 = Monday
  final List<DietMeal> meals;
  final String notes;

  const DietDay({
    required this.dayOfWeek,
    this.meals = const [],
    this.notes = '',
  });

  factory DietDay.fromJson(Map<String, dynamic> json) => DietDay(
        dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 0,
        meals: (json['meals'] as List<dynamic>? ?? [])
            .map((m) => DietMeal.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
        notes: json['notes']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        'meals': meals.map((m) => m.toJson()).toList(),
        'notes': notes,
      };

  static const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  String get dayName => dayNames[dayOfWeek.clamp(0, 6)];

  static int mondayBasedDayOfWeek([DateTime? date]) {
    final d = date ?? DateTime.now();
    return d.weekday - 1; // DateTime.weekday: Mon=1 … Sun=7
  }
}

class DietPlan {
  final String? id;
  final String? coachId;
  final String? clientId;
  final String? fitnessClassId;
  final String title;
  final String goal;
  final String planType; // single_day | weekly
  final int? targetDayOfWeek; // single_day: which weekday
  final String? targetDayName;
  final List<DietMeal> meals;
  final List<DietDay> days;
  final List<DietMeal> todaysMeals;
  final int? todayDayOfWeek;
  final String? todayDayName;
  final int dailyCalories;
  final String notes;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? assigneeName;
  final Map<String, dynamic>? client;
  final Map<String, dynamic>? coach;
  final Map<String, dynamic>? fitnessClass;

  const DietPlan({
    this.id,
    this.coachId,
    this.clientId,
    this.fitnessClassId,
    this.title = 'Diet Plan',
    this.goal = 'maintenance',
    this.planType = 'single_day',
    this.targetDayOfWeek,
    this.targetDayName,
    this.meals = const [],
    this.days = const [],
    this.todaysMeals = const [],
    this.todayDayOfWeek,
    this.todayDayName,
    this.dailyCalories = 2000,
    this.notes = '',
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
    this.assigneeName,
    this.client,
    this.coach,
    this.fitnessClass,
  });

  bool get isGroupPlan => fitnessClassId != null || fitnessClass != null;
  bool get isWeekly => planType == 'weekly';

  /// Meals for a given Monday-based day index, or today's / flat meals.
  List<DietMeal> mealsForDay([int? dayOfWeek]) {
    final dow = dayOfWeek ?? todayDayOfWeek ?? DietDay.mondayBasedDayOfWeek();
    if (isWeekly && days.isNotEmpty) {
      for (final d in days) {
        if (d.dayOfWeek == dow) return d.meals;
      }
      return [];
    }
    // Single-day plan: only show meals on the checked target day
    if (targetDayOfWeek != null && dow != targetDayOfWeek) {
      return const [];
    }
    if (todaysMeals.isNotEmpty && dayOfWeek == null) return todaysMeals;
    return meals;
  }

  factory DietPlan.fromJson(Map<String, dynamic> json) {
    final days = (json['days'] as List<dynamic>? ?? [])
        .map((d) => DietDay.fromJson(Map<String, dynamic>.from(d as Map)))
        .toList();
    final meals = (json['meals'] as List<dynamic>? ?? [])
        .map((m) => DietMeal.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
    final todays = (json['todaysMeals'] as List<dynamic>? ?? [])
        .map((m) => DietMeal.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
    return DietPlan(
      id: json['_id']?.toString(),
      coachId: json['coach'] is Map ? json['coach']['_id']?.toString() : json['coach']?.toString(),
      clientId: json['client'] is Map ? json['client']['_id']?.toString() : json['client']?.toString(),
      fitnessClassId: json['fitnessClass'] is Map
          ? json['fitnessClass']['_id']?.toString()
          : json['fitnessClass']?.toString(),
      title: json['title']?.toString() ?? 'Diet Plan',
      goal: json['goal']?.toString() ?? 'maintenance',
      planType: json['planType']?.toString() == 'weekly' ? 'weekly' : 'single_day',
      targetDayOfWeek: (json['targetDayOfWeek'] as num?)?.toInt(),
      targetDayName: json['targetDayName']?.toString(),
      meals: meals,
      days: days,
      todaysMeals: todays,
      todayDayOfWeek: (json['todayDayOfWeek'] as num?)?.toInt(),
      todayDayName: json['todayDayName']?.toString(),
      dailyCalories: (json['dailyCalories'] as num?)?.toInt() ?? 2000,
      notes: json['notes']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      assigneeName: json['assigneeName']?.toString(),
      client: json['client'] is Map ? Map<String, dynamic>.from(json['client'] as Map) : null,
      coach: json['coach'] is Map ? Map<String, dynamic>.from(json['coach'] as Map) : null,
      fitnessClass: json['fitnessClass'] is Map ? Map<String, dynamic>.from(json['fitnessClass'] as Map) : null,
    );
  }

  String get displayAssigneeName {
    if (assigneeName != null && assigneeName!.isNotEmpty) return assigneeName!;
    final clientName = ((client?['full_name'] ?? client?['name'] ?? client?['username']) ?? '')
        .toString()
        .trim();
    if (clientName.isNotEmpty) return clientName;
    if (fitnessClass?['title'] != null) return fitnessClass!['title'].toString();
    return isGroupPlan ? 'Group' : 'Client';
  }

  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'completed':
      case 'archived':
        return 'Completed';
      case 'active':
      default:
        return 'Active';
    }
  }

  String get planTypeLabel {
    if (isWeekly) return 'Weekly Plan';
    if (targetDayOfWeek != null) {
      final name = targetDayName ?? DietDay.dayNames[targetDayOfWeek!.clamp(0, 6)];
      return 'Single Day · $name';
    }
    return 'Single Day Plan';
  }

  Map<String, dynamic> toCreatePayload({
    String? clientId,
    String? fitnessClassId,
    String? planId,
    String? status,
  }) => {
        if (planId != null) 'planId': planId,
        if (clientId != null) 'clientId': clientId,
        if (fitnessClassId != null) 'fitnessClassId': fitnessClassId,
        if (status != null) 'status': status,
        'title': title,
        'goal': goal,
        'planType': planType,
        'dailyCalories': dailyCalories,
        'notes': notes,
        if (isWeekly)
          'days': days.map((d) => d.toJson()).toList()
        else ...{
          'meals': meals.map((m) => m.toJson()).toList(),
          if (targetDayOfWeek != null) 'targetDayOfWeek': targetDayOfWeek,
        },
      };

  Map<String, dynamic> toCreatePayloadLegacy({String? clientId, String? fitnessClassId}) =>
      toCreatePayload(clientId: clientId, fitnessClassId: fitnessClassId);

  String get goalLabel {
    switch (goal) {
      case 'weight_loss':
        return 'Weight Loss';
      case 'muscle_gain':
        return 'Muscle Gain';
      default:
        return 'Maintenance';
    }
  }
}

class DietAdherence {
  final String? id;
  final DateTime date;
  final double? weightKg;
  final int caloriesConsumed;
  final int targetCalories;
  final bool followedPlan;
  final int adherencePercent;
  final bool coachMarked;
  final String notes;

  const DietAdherence({
    this.id,
    required this.date,
    this.weightKg,
    this.caloriesConsumed = 0,
    this.targetCalories = 0,
    this.followedPlan = false,
    this.adherencePercent = 0,
    this.coachMarked = false,
    this.notes = '',
  });

  factory DietAdherence.fromJson(Map<String, dynamic> json) => DietAdherence(
        id: json['_id']?.toString(),
        date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        caloriesConsumed: (json['caloriesConsumed'] as num?)?.toInt() ?? 0,
        targetCalories: (json['targetCalories'] as num?)?.toInt() ?? 0,
        followedPlan: json['followedPlan'] == true,
        adherencePercent: (json['adherencePercent'] as num?)?.toInt() ?? 0,
        coachMarked: json['coachMarked'] == true,
        notes: json['notes']?.toString() ?? '',
      );
}
