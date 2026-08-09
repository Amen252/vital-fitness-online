class DietMeal {
  final String? id;
  final String type;
  final String name;
  final String description;
  final List<String> foodItems;
  final String portionSize;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  final String reminderTime;
  final String prepInstructions;
  final String mealNotes;

  const DietMeal({
    this.id,
    required this.type,
    this.name = '',
    this.description = '',
    this.foodItems = const [],
    this.portionSize = '',
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fats = 0,
    this.reminderTime = '',
    this.prepInstructions = '',
    this.mealNotes = '',
  });

  factory DietMeal.fromJson(Map<String, dynamic> json) => DietMeal(
        id: json['_id']?.toString(),
        type: json['type']?.toString() ?? 'snacks',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        foodItems: (json['foodItems'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .where((s) => s.trim().isNotEmpty)
            .toList(),
        portionSize: json['portionSize']?.toString() ?? '',
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        protein: (json['protein'] as num?)?.toInt() ?? 0,
        carbs: (json['carbs'] as num?)?.toInt() ?? 0,
        fats: (json['fats'] as num?)?.toInt() ?? 0,
        reminderTime: json['reminderTime']?.toString() ?? '',
        prepInstructions: json['prepInstructions']?.toString() ?? '',
        mealNotes: json['mealNotes']?.toString() ?? json['notes']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'name': name,
        'description': description,
        'foodItems': foodItems,
        'portionSize': portionSize,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fats': fats,
        'reminderTime': reminderTime,
        'prepInstructions': prepInstructions,
        'mealNotes': mealNotes,
      };

  bool get hasContent =>
      name.trim().isNotEmpty ||
      description.trim().isNotEmpty ||
      foodItems.isNotEmpty ||
      portionSize.trim().isNotEmpty ||
      calories > 0 ||
      reminderTime.trim().isNotEmpty;

  String get macrosLabel {
    final parts = <String>[];
    if (calories > 0) parts.add('$calories kcal');
    if (protein > 0) parts.add('P ${protein}g');
    if (carbs > 0) parts.add('C ${carbs}g');
    if (fats > 0) parts.add('F ${fats}g');
    return parts.join(' · ');
  }

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
  final DateTime? date;
  final List<DietMeal> meals;
  final String notes;

  const DietDay({
    required this.dayOfWeek,
    this.date,
    this.meals = const [],
    this.notes = '',
  });

  factory DietDay.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final rawDate = json['date'] ?? json['dateOnly'];
    if (rawDate != null) {
      final s = rawDate.toString();
      final datePart = s.contains('T') ? s.split('T').first : s.trim();
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datePart)) {
        final parts = datePart.split('-').map(int.parse).toList();
        parsedDate = DateTime(parts[0], parts[1], parts[2]);
      } else {
        parsedDate = DateTime.tryParse(s);
        if (parsedDate != null) {
          parsedDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
        }
      }
    }
    return DietDay(
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 0,
      date: parsedDate,
      meals: (json['meals'] as List<dynamic>? ?? [])
          .map((m) => DietMeal.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList(),
      notes: json['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        if (date != null)
          'date':
              '${date!.year.toString().padLeft(4, '0')}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
        'meals': meals.map((m) => m.toJson()).toList(),
        'notes': notes,
      };

  static const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const monthNames = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String get dayName => dayNames[dayOfWeek.clamp(0, 6)];

  /// e.g. "Monday, August 10"
  String get dayAndDateLabel {
    if (date == null) return dayName;
    return '$dayName, ${monthNames[date!.month]} ${date!.day}';
  }

  String get shortDateLabel {
    if (date == null) return '';
    return '${date!.month}/${date!.day}';
  }

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
  final DateTime? weekStartDate;
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
    this.weekStartDate,
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

  /// Calendar date for a Monday-based day index within this weekly plan.
  DateTime? dateForDayOfWeek(int dayOfWeek) {
    for (final d in days) {
      if (d.dayOfWeek == dayOfWeek && d.date != null) return d.date;
    }
    if (weekStartDate == null) return null;
    final start = DateTime(weekStartDate!.year, weekStartDate!.month, weekStartDate!.day);
    return start.add(Duration(days: dayOfWeek.clamp(0, 6)));
  }

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

    DateTime? weekStart;
    final rawWeek = json['weekStartDate']?.toString();
    if (rawWeek != null && rawWeek.isNotEmpty) {
      final datePart = rawWeek.contains('T') ? rawWeek.split('T').first : rawWeek.trim();
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datePart)) {
        final parts = datePart.split('-').map(int.parse).toList();
        weekStart = DateTime(parts[0], parts[1], parts[2]);
      } else {
        final parsed = DateTime.tryParse(rawWeek);
        if (parsed != null) weekStart = DateTime(parsed.year, parsed.month, parsed.day);
      }
    }

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
      weekStartDate: weekStart,
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
      case 'archived':
        return 'Archived';
      case 'completed':
        return 'Previous';
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
        if (isWeekly) ...{
          'days': days.map((d) => d.toJson()).toList(),
          if (weekStartDate != null)
            'weekStartDate':
                '${weekStartDate!.year.toString().padLeft(4, '0')}-${weekStartDate!.month.toString().padLeft(2, '0')}-${weekStartDate!.day.toString().padLeft(2, '0')}',
        } else ...{
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
