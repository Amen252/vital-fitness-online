class WorkoutSet {
  final int? reps;
  final double? weight;

  WorkoutSet({this.reps, this.weight});

  factory WorkoutSet.fromJson(Map<String, dynamic>? json) {
    if (json == null) return WorkoutSet();
    return WorkoutSet(
      reps: (json['reps'] as num?)?.toInt(),
      weight: (json['weight'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reps': reps,
      'weight': weight,
    };
  }
}

class ActivityLog {
  final String id;
  final String activityType;
  final int durationMinutes;
  final double caloriesBurned;
  final List<WorkoutSet> sets;
  final String status;
  final DateTime date;

  ActivityLog({
    required this.id,
    required this.activityType,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.sets,
    required this.status,
    required this.date,
  });

  factory ActivityLog.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ActivityLog(
        id: '',
        activityType: 'Unknown',
        durationMinutes: 0,
        caloriesBurned: 0.0,
        sets: [],
        status: 'pending',
        date: DateTime.now(),
      );
    }

    return ActivityLog(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      activityType: json['activityType']?.toString() ?? 'Workout',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      caloriesBurned: (json['caloriesBurned'] as num?)?.toDouble() ?? 0.0,
      sets: json['sets'] != null
          ? (json['sets'] as List)
              .map((s) => WorkoutSet.fromJson(s as Map<String, dynamic>?))
              .toList()
          : [],
      status: json['status']?.toString() ?? 'pending',
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
