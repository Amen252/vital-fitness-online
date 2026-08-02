import 'activity_log_model.dart';

class ProgressSummary {
  final double caloriesIn;
  final double caloriesOut;
  final double hydration;
  final double netCalories;
  final double? bmi;
  final int logCount;

  ProgressSummary({
    required this.caloriesIn,
    required this.caloriesOut,
    required this.hydration,
    required this.netCalories,
    this.bmi,
    required this.logCount,
  });

  factory ProgressSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ProgressSummary(
        caloriesIn: 0.0,
        caloriesOut: 0.0,
        hydration: 0.0,
        netCalories: 0.0,
        logCount: 0,
      );
    }

    return ProgressSummary(
      caloriesIn: (json['caloriesIn'] as num?)?.toDouble() ?? 0.0,
      caloriesOut: (json['caloriesOut'] as num?)?.toDouble() ?? 0.0,
      hydration: (json['hydration'] as num?)?.toDouble() ?? 0.0,
      netCalories: (json['netCalories'] as num?)?.toDouble() ?? 0.0,
      bmi: (json['bmi'] as num?)?.toDouble(),
      logCount: (json['logCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProgressTrendPoint {
  final String label;
  final double value;

  const ProgressTrendPoint({required this.label, required this.value});

  factory ProgressTrendPoint.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ProgressTrendPoint(label: '', value: 0);
    return ProgressTrendPoint(
      label: json['label']?.toString() ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Short weekday from YYYY-MM-DD.
  String get shortWeekday {
    final parsed = DateTime.tryParse(label);
    if (parsed == null) return label.isNotEmpty ? label[0] : '';
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return days[parsed.weekday - 1];
  }
}

class ProgressTrends {
  final List<ProgressTrendPoint> caloriesIn;
  final List<ProgressTrendPoint> caloriesOut;
  final List<ProgressTrendPoint> hydration;

  const ProgressTrends({
    this.caloriesIn = const [],
    this.caloriesOut = const [],
    this.hydration = const [],
  });

  factory ProgressTrends.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ProgressTrends();

    List<ProgressTrendPoint> parse(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => ProgressTrendPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return ProgressTrends(
      caloriesIn: parse('caloriesIn'),
      caloriesOut: parse('caloriesOut'),
      hydration: parse('hydration'),
    );
  }
}

class HealthReport {
  final String status;
  final String message;
  final List<String> suggestions;

  HealthReport({
    required this.status,
    required this.message,
    required this.suggestions,
  });

  factory HealthReport.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return HealthReport(status: 'Normal', message: 'No notifications.', suggestions: []);
    }
    return HealthReport(
      status: json['status']?.toString() ?? 'Normal',
      message: json['message']?.toString() ?? 'No notifications.',
      suggestions: json['suggestions'] != null
          ? List<String>.from(json['suggestions'] as List)
          : [],
    );
  }
}

class ComplianceFeedback {
  final double score;
  final String feedback;

  ComplianceFeedback({
    required this.score,
    required this.feedback,
  });

  factory ComplianceFeedback.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ComplianceFeedback(score: 0.0, feedback: 'Keep logging your habits!');
    }
    return ComplianceFeedback(
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      feedback: json['feedback']?.toString() ?? 'Keep logging your habits!',
    );
  }
}

class ProgressData {
  final ProgressSummary summary;
  final ProgressTrends trends;
  final List<String> reports;
  final Map<String, dynamic> compliance;
  final List<ActivityLog> recentActivities;

  ProgressData({
    required this.summary,
    this.trends = const ProgressTrends(),
    required this.reports,
    required this.compliance,
    required this.recentActivities,
  });

  factory ProgressData.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ProgressData(
        summary: ProgressSummary.fromJson(null),
        trends: const ProgressTrends(),
        reports: [],
        compliance: {},
        recentActivities: [],
      );
    }

    List<String> rawReports = [];
    if (json['reports'] != null) {
      if (json['reports'] is List) {
        rawReports = List<String>.from(json['reports'] as List);
      } else if (json['reports'] is Map) {
        final map = json['reports'] as Map;
        rawReports = map.values.map((v) => v.toString()).toList();
      } else {
        rawReports = [json['reports'].toString()];
      }
    }

    List<ActivityLog> activities = [];
    if (json['recentLogs'] != null && json['recentLogs']['activities'] != null) {
      final list = json['recentLogs']['activities'] as List;
      activities = list.map((a) => ActivityLog.fromJson(a as Map<String, dynamic>?)).toList();
    }

    return ProgressData(
      summary: ProgressSummary.fromJson(json['summary'] as Map<String, dynamic>?),
      trends: ProgressTrends.fromJson(json['trends'] as Map<String, dynamic>?),
      reports: rawReports,
      compliance: json['compliance'] != null ? json['compliance'] as Map<String, dynamic> : {},
      recentActivities: activities,
    );
  }
}
