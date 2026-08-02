import 'package:flutter/material.dart';

import '../screens/dashboard/widgets/coach_home/coach_dashboard_theme.dart';
import '../services/api_service.dart';
import '../utils/date_utils.dart';
import '../utils/workout_media_urls.dart';

enum CoachWorkoutDetailKind { template, schedule, weeklyPlan }

Future<void> showCoachWorkoutDetailSheet(
  BuildContext context, {
  required CoachWorkoutDetailKind kind,
  required Map<String, dynamic> data,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CoachWorkoutDetailSheet(kind: kind, data: data),
  );
}

class _CoachWorkoutDetailSheet extends StatelessWidget {
  final CoachWorkoutDetailKind kind;
  final Map<String, dynamic> data;

  const _CoachWorkoutDetailSheet({
    required this.kind,
    required this.data,
  });

  Map<String, dynamic>? get _template {
    final raw = data['workoutTemplate'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return kind == CoachWorkoutDetailKind.template ? data : null;
  }

  List<dynamic> _exercisesFor({List<dynamic>? override}) {
    if (override != null && override.isNotEmpty) return override;
    final scheduleExercises = data['exercises'] as List<dynamic>?;
    if (scheduleExercises != null && scheduleExercises.isNotEmpty) return scheduleExercises;
    return _template?['exercises'] as List<dynamic>? ?? const [];
  }

  String? _derivedFromExercises(String key) {
    final values = _exercisesFor()
        .map((raw) => raw is Map ? raw[key]?.toString().trim() : null)
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();
    if (values.isEmpty) return null;
    return values.join(', ');
  }

  String _title() {
    switch (kind) {
      case CoachWorkoutDetailKind.template:
        return data['title']?.toString() ?? 'Workout';
      case CoachWorkoutDetailKind.schedule:
        return data['title']?.toString() ?? _template?['title']?.toString() ?? 'Workout';
      case CoachWorkoutDetailKind.weeklyPlan:
        return data['title']?.toString() ?? 'Weekly Workout Plan';
    }
  }

  String? _description() {
    final direct = data['description']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    return _template?['description']?.toString().trim();
  }

  String? _level() => _template?['level']?.toString() ?? data['level']?.toString();

  String? _instructions() {
    final notes = data['notes']?.toString().trim();
    if (notes != null && notes.isNotEmpty) return notes;
    final templateNotes = _template?['notes']?.toString().trim();
    if (templateNotes != null && templateNotes.isNotEmpty) return templateNotes;
    return _template?['instructions']?.toString().trim() ?? data['instructions']?.toString().trim();
  }

  String? _status() {
    switch (kind) {
      case CoachWorkoutDetailKind.template:
        return data['status']?.toString();
      case CoachWorkoutDetailKind.schedule:
        return data['status']?.toString();
      case CoachWorkoutDetailKind.weeklyPlan:
        return data['status']?.toString();
    }
  }

  String? _assigneeLabel() {
    if (data['fitnessClass'] is Map) {
      return 'Group: ${data['fitnessClass']?['title'] ?? 'Group'}';
    }
    if (data['client'] is Map) {
      return 'User: ${ApiService.displayName(Map<dynamic, dynamic>.from(data['client'] as Map), fallback: 'Client')}';
    }
    return null;
  }

  String _statusLabel(String? raw) {
    if (raw == null || raw.isEmpty) return 'Unknown';
    switch (raw) {
      case 'active':
        return 'Active';
      case 'archived':
        return 'Archived';
      case 'scheduled':
        return 'Scheduled';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'pending_review':
        return 'Pending Review';
      case 'pending':
        return 'Assigned';
      case 'missed':
        return 'Missed';
      default:
        return raw[0].toUpperCase() + raw.substring(1).replaceAll('_', ' ');
    }
  }

  Color _statusColor(String? raw, bool isDark) {
    switch (raw) {
      case 'active':
      case 'completed':
        return CoachDashboardTheme.success;
      case 'archived':
      case 'cancelled':
        return isDark ? Colors.white38 : Colors.grey;
      case 'scheduled':
      case 'pending':
        return CoachDashboardTheme.primary;
      case 'pending_review':
        return CoachDashboardTheme.warning;
      case 'missed':
        return CoachDashboardTheme.danger;
      default:
        return CoachDashboardTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exercises = _exercisesFor();
    final status = _status();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181B24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_title(), style: CoachDashboardTheme.sectionTitle(isDark).copyWith(fontSize: 20)),
                          const SizedBox(height: 4),
                          Text(
                            kind == CoachWorkoutDetailKind.template
                                ? 'Workout template'
                                : kind == CoachWorkoutDetailKind.schedule
                                    ? 'Scheduled workout'
                                    : 'Weekly workout plan',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (status != null && status.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 2, right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(status, isDark).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _statusColor(status, isDark),
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: isDark ? Colors.white54 : Colors.black45),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    if (_description() case final desc?)
                      _Section(
                        isDark: isDark,
                        title: 'Description',
                        child: Text(
                          desc,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: isDark ? Colors.white70 : CoachDashboardTheme.textPrimary,
                          ),
                        ),
                      ),
                    _Section(
                      isDark: isDark,
                      title: 'Overview',
                      child: Column(
                        children: [
                          _DetailRow(isDark: isDark, label: 'Difficulty', value: _level() ?? 'Not specified'),
                          _DetailRow(
                            isDark: isDark,
                            label: 'Category',
                            value: data['category']?.toString() ?? _derivedFromExercises('category') ?? 'Not specified',
                          ),
                          _DetailRow(
                            isDark: isDark,
                            label: 'Target muscle',
                            value: data['muscleGroup']?.toString()
                                ?? data['muscle']?.toString()
                                ?? _derivedFromExercises('muscle')
                                ?? _derivedFromExercises('muscleGroup')
                                ?? 'Not specified',
                          ),
                          if (kind != CoachWorkoutDetailKind.template)
                            _DetailRow(isDark: isDark, label: 'Workout title', value: _template?['title']?.toString() ?? _title()),
                          if (_assigneeLabel() case final assignee?)
                            _DetailRow(isDark: isDark, label: 'Assigned to', value: assignee),
                          if (kind == CoachWorkoutDetailKind.schedule) ...[
                            _DetailRow(
                              isDark: isDark,
                              label: 'Schedule',
                              value: formatScheduleRange(
                                data['startDateTime']?.toString(),
                                data['endDateTime']?.toString(),
                              ),
                            ),
                            if (data['durationMinutes'] != null)
                              _DetailRow(isDark: isDark, label: 'Duration', value: '${data['durationMinutes']} min'),
                            if (data['reminderEnabled'] == true)
                              _DetailRow(
                                isDark: isDark,
                                label: 'Reminder',
                                value: '${data['reminderMinutesBefore'] ?? 30} min before',
                              ),
                            if (data['weeklyPlan'] is Map)
                              _DetailRow(
                                isDark: isDark,
                                label: 'Weekly plan',
                                value: data['weeklyPlan']?['title']?.toString() ?? 'Linked plan',
                              ),
                          ],
                          if (kind == CoachWorkoutDetailKind.weeklyPlan) ...[
                            if (parseApiDateOnly(data['weekStartDate']?.toString()) case final weekStart?)
                              _DetailRow(isDark: isDark, label: 'Week', value: formatWeekRange(weekStart)),
                            if (_template?['title'] case final workoutTitle?)
                              _DetailRow(isDark: isDark, label: 'Primary workout', value: workoutTitle),
                            if (data['reminderEnabled'] == true)
                              _DetailRow(
                                isDark: isDark,
                                label: 'Reminder',
                                value: '${data['reminderMinutesBefore'] ?? 30} min before',
                              ),
                          ],
                          if (data['createdAt'] != null)
                            _DetailRow(isDark: isDark, label: 'Created', value: formatApiDateTime(data['createdAt']?.toString())),
                          if (data['updatedAt'] != null)
                            _DetailRow(isDark: isDark, label: 'Updated', value: formatApiDateTime(data['updatedAt']?.toString())),
                        ],
                      ),
                    ),
                    if (_instructions() case final instructions?)
                      _Section(
                        isDark: isDark,
                        title: 'Instructions',
                        child: Text(
                          instructions,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: isDark ? Colors.white70 : CoachDashboardTheme.textPrimary,
                          ),
                        ),
                      ),
                    if (kind == CoachWorkoutDetailKind.weeklyPlan)
                      ..._weeklyDaySections(isDark)
                    else if (exercises.isNotEmpty)
                      _Section(
                        isDark: isDark,
                        title: 'Exercises (${exercises.length})',
                        child: Column(
                          children: exercises.map((raw) {
                            final map = raw is Map
                                ? Map<dynamic, dynamic>.from(raw)
                                : <dynamic, dynamic>{'name': raw?.toString() ?? 'Exercise'};
                            return _ExerciseDetailCard(exercise: map, isDark: isDark);
                          }).toList(),
                        ),
                      ),
                    if (kind == CoachWorkoutDetailKind.schedule || kind == CoachWorkoutDetailKind.weeklyPlan)
                      _progressSection(isDark),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _weeklyDaySections(bool isDark) {
    const dayLabels = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const shortLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final days = data['days'] as List<dynamic>? ?? [];
    if (days.isEmpty) return const [];

    return days.map((raw) {
      if (raw is! Map) return const SizedBox.shrink();
      final day = Map<String, dynamic>.from(raw);
      final index = day['dayOfWeek'] as int? ?? 0;
      final label = dayLabels[index.clamp(0, 6)];
      final short = shortLabels[index.clamp(0, 6)];
      final offDay = day['offDay'] == true;
      final enabled = day['enabled'] == true && !offDay;
      final dayExercises = day['exercises'] as List<dynamic>? ?? [];
      final start = day['startTime']?.toString() ?? '';
      final end = day['endTime']?.toString() ?? '';
      final dayNotes = day['notes']?.toString().trim() ?? '';
      String? dayTemplate;
      if (day['workoutTemplate'] is Map) {
        dayTemplate = (day['workoutTemplate'] as Map)['title']?.toString();
      }

      return _Section(
        isDark: isDark,
        title: label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _DayChip(
                  label: offDay ? 'Off day' : (enabled ? 'Active' : 'Inactive'),
                  color: offDay
                      ? Colors.blueGrey
                      : (enabled ? CoachDashboardTheme.success : Colors.grey),
                  isDark: isDark,
                ),
                if (start.isNotEmpty && end.isNotEmpty)
                  _DayChip(label: '$short · $start–$end', color: CoachDashboardTheme.primary, isDark: isDark),
                if (dayTemplate != null && dayTemplate.isNotEmpty)
                  _DayChip(label: dayTemplate, color: CoachDashboardTheme.accent, isDark: isDark),
              ],
            ),
            if (dayNotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(dayNotes, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : CoachDashboardTheme.textPrimary)),
            ],
            if (enabled && dayExercises.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...dayExercises.map((ex) {
                final map = ex is Map
                    ? Map<dynamic, dynamic>.from(ex)
                    : <dynamic, dynamic>{'name': ex?.toString() ?? 'Exercise'};
                return _ExerciseDetailCard(exercise: map, isDark: isDark);
              }),
            ] else if (enabled && dayExercises.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No exercises listed for this day.',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
                ),
              ),
            if (day['progress'] is Map) ...[
              const SizedBox(height: 10),
              ..._completionLines(day['progress'] as Map<String, dynamic>, isDark),
            ],
          ],
        ),
      );
    }).toList();
  }

  Widget _progressSection(bool isDark) {
    final progress = data['summary'] as Map<String, dynamic>? ?? data['progress'] as Map<String, dynamic>?;
    if (progress == null) return const SizedBox.shrink();

    return _Section(
      isDark: isDark,
      title: 'Progress & status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(
            isDark: isDark,
            label: 'Summary',
            value: '${progress['completed'] ?? 0} done · ${progress['pending'] ?? 0} pending · ${progress['missed'] ?? 0} missed',
          ),
          const SizedBox(height: 8),
          ..._completionLines(progress, isDark),
        ],
      ),
    );
  }

  List<Widget> _completionLines(Map<String, dynamic> progress, bool isDark) {
    final completions = progress['completions'] as List<dynamic>? ?? const [];
    if (completions.isEmpty) return const [];

    return completions.map((raw) {
      if (raw is! Map) return const SizedBox.shrink();
      final completion = Map<String, dynamic>.from(raw);
      final user = completion['user'] is Map ? Map<dynamic, dynamic>.from(completion['user'] as Map) : null;
      final name = ApiService.displayName(user, fallback: 'Member');
      final status = completion['status']?.toString() ?? 'pending';
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white : CoachDashboardTheme.textPrimary),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor(status, isDark).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _statusLabel(status),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(status, isDark)),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _Section extends StatelessWidget {
  final bool isDark;
  final String title;
  final Widget child;

  const _Section({
    required this.isDark,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: CoachDashboardTheme.sectionTitle(isDark)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: CoachDashboardTheme.cardDecoration(isDark),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final bool isDark;
  final String label;
  final String value;

  const _DetailRow({
    required this.isDark,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : CoachDashboardTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;

  const _DayChip({
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _ExerciseDetailCard extends StatelessWidget {
  final Map<dynamic, dynamic> exercise;
  final bool isDark;

  const _ExerciseDetailCard({
    required this.exercise,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final name = exercise['name']?.toString() ?? 'Exercise';
    final equipment = exercise['equipment']?.toString().trim() ?? '';
    final instructions = exercise['instructions']?.toString().trim() ?? exercise['notes']?.toString().trim() ?? '';
    final category = exercise['category']?.toString().trim() ?? '';
    final muscle = exercise['muscle']?.toString().trim() ?? exercise['muscleGroup']?.toString().trim() ?? '';

    final details = <String>[];
    if (exercise['sets'] != null || exercise['reps'] != null) {
      details.add('${exercise['sets'] ?? '-'} sets × ${exercise['reps'] ?? '-'} reps');
    }
    if (exercise['durationMinutes'] != null) details.add('${exercise['durationMinutes']} min');
    if (exercise['restSeconds'] != null) details.add('${exercise['restSeconds']}s rest');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12151C) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : CoachDashboardTheme.textPrimary)),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              details.join(' · '),
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : CoachDashboardTheme.textSecondary),
            ),
          ],
          if (category.isNotEmpty)
            _ExerciseMetaRow(isDark: isDark, label: 'Category', value: category),
          if (muscle.isNotEmpty)
            _ExerciseMetaRow(isDark: isDark, label: 'Target muscle', value: muscle),
          if (equipment.isNotEmpty)
            _ExerciseMetaRow(isDark: isDark, label: 'Equipment', value: equipment),
          if (instructions.isNotEmpty)
            _ExerciseMetaRow(isDark: isDark, label: 'Instructions', value: instructions),
          if (WorkoutMediaUrls.normalize(exercise['demoVideoUrl']?.toString()) case final videoUrl?) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => WorkoutMediaUrls.open(context, videoUrl),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_fill_rounded, size: 18, color: CoachDashboardTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Watch demo video',
                    style: TextStyle(
                      color: CoachDashboardTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      decorationColor: CoachDashboardTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (WorkoutMediaUrls.normalize(exercise['demoImageUrl']?.toString()) case final imageUrl?) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => WorkoutMediaUrls.open(context, imageUrl),
              child: Text(
                'View demo image',
                style: TextStyle(
                  color: CoachDashboardTheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExerciseMetaRow extends StatelessWidget {
  final bool isDark;
  final String label;
  final String value;

  const _ExerciseMetaRow({
    required this.isDark,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.white70 : CoachDashboardTheme.textPrimary),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
