import 'package:flutter/material.dart';

import '../screens/dashboard/widgets/coach_home/coach_dashboard_theme.dart';
import '../services/api_service.dart';
import '../utils/date_utils.dart';
import '../utils/workout_media_urls.dart';
import 'workout_completion_proof_view.dart';
import 'workout_mark_complete_control.dart';

typedef UserWorkoutSubmitCallback = Future<void> Function(Map<String, dynamic> plan);

Future<void> showUserWorkoutDetailSheet(
  BuildContext context, {
  required Map<String, dynamic> workout,
  UserWorkoutSubmitCallback? onSubmitProof,
  bool isSubmitting = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _UserWorkoutDetailSheet(
      workout: workout,
      onSubmitProof: onSubmitProof,
      isSubmitting: isSubmitting,
    ),
  );
}

class _UserWorkoutDetailSheet extends StatelessWidget {
  final Map<String, dynamic> workout;
  final UserWorkoutSubmitCallback? onSubmitProof;
  final bool isSubmitting;

  const _UserWorkoutDetailSheet({
    required this.workout,
    this.onSubmitProof,
    this.isSubmitting = false,
  });

  String get _source => workout['source']?.toString() ?? 'exercise_plan';

  Map<String, dynamic>? get _completion =>
      workout['completion'] is Map ? Map<String, dynamic>.from(workout['completion'] as Map) : null;

  String get _status => _completion?['status']?.toString() ?? 'pending';

  bool get _canSubmit {
    if (_source == 'weekly_plan') return false;
    if (_completion?['completable'] == false) return false;
    return _status == 'pending' || _status == 'missed';
  }

  String _coachName() {
    if (workout['coach'] is Map) {
      return ApiService.displayName(
        Map<dynamic, dynamic>.from(workout['coach'] as Map),
        fallback: 'Coach',
      );
    }
    return 'Your coach';
  }

  List<dynamic> _exercises() {
    final direct = workout['exercises'] as List<dynamic>?;
    if (direct != null && direct.isNotEmpty) return direct;
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = workout['title']?.toString() ?? 'Workout';
    final level = workout['level']?.toString() ?? 'Beginner';
    final description = workout['description']?.toString().trim() ?? '';
    final instructions = workout['instructions']?.toString().trim()
        ?? workout['notes']?.toString().trim()
        ?? '';
    final feedback = _completion?['coachFeedback']?.toString().trim() ?? '';
    final exercises = _exercises();
    final weeklyDays = (workout['days'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((d) => Map<String, dynamic>.from(d))
        .where((d) => d['enabled'] == true && d['offDay'] != true)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
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
                          Text(title, style: CoachDashboardTheme.sectionTitle(isDark).copyWith(fontSize: 20)),
                          const SizedBox(height: 4),
                          Text(
                            'Assigned by ${_coachName()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusChip(status: _status, isDark: isDark),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: isDark ? Colors.white54 : Colors.black45),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    _Section(
                      isDark: isDark,
                      title: 'Overview',
                      child: Column(
                        children: [
                          _DetailRow(isDark: isDark, label: 'Difficulty', value: level),
                          _DetailRow(isDark: isDark, label: 'Type', value: _sourceLabel(_source)),
                          if (workout['assigneeType'] == 'group' && workout['groupName'] != null)
                            _DetailRow(isDark: isDark, label: 'Group', value: workout['groupName'].toString()),
                          if (_source == 'schedule' && workout['startDateTime'] != null)
                            _DetailRow(
                              isDark: isDark,
                              label: 'Scheduled',
                              value: formatScheduleRange(
                                workout['startDateTime']?.toString(),
                                workout['endDateTime']?.toString(),
                              ),
                            ),
                          if (workout['durationMinutes'] != null)
                            _DetailRow(isDark: isDark, label: 'Duration', value: '${workout['durationMinutes']} min'),
                          if (parseApiDateOnly(workout['weekStartDate']?.toString()) case final weekStart?)
                            _DetailRow(isDark: isDark, label: 'Week', value: formatWeekRange(weekStart)),
                          if (_completion?['submittedAt'] != null)
                            _DetailRow(
                              isDark: isDark,
                              label: 'Submitted',
                              value: formatApiDateTime(_completion!['submittedAt']?.toString()),
                            ),
                          if (_completion?['completedAt'] != null)
                            _DetailRow(
                              isDark: isDark,
                              label: 'Approved',
                              value: formatApiDateTime(_completion!['completedAt']?.toString()),
                            ),
                        ],
                      ),
                    ),
                    if (description.isNotEmpty)
                      _Section(
                        isDark: isDark,
                        title: 'Description',
                        child: Text(
                          description,
                          style: TextStyle(fontSize: 14, height: 1.45, color: isDark ? Colors.white70 : CoachDashboardTheme.textPrimary),
                        ),
                      ),
                    if (instructions.isNotEmpty)
                      _Section(
                        isDark: isDark,
                        title: 'Instructions',
                        child: Text(
                          instructions,
                          style: TextStyle(fontSize: 14, height: 1.45, color: isDark ? Colors.white70 : CoachDashboardTheme.textPrimary),
                        ),
                      ),
                    if (_completion != null &&
                        (_status == 'pending_review' ||
                            _status == 'completed' ||
                            _completion!['hasProofPhoto'] == true ||
                            (_completion!['notes']?.toString().trim().isNotEmpty ?? false)))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: WorkoutCompletionProofView(
                          completion: _completion!,
                          isDark: isDark,
                          title: 'Your submission',
                        ),
                      ),
                    if (feedback.isNotEmpty &&
                        !(_status == 'pending_review' || _status == 'completed' || _completion?['hasProofPhoto'] == true))
                      _Section(
                        isDark: isDark,
                        title: 'Coach feedback',
                        child: Text(
                          feedback,
                          style: TextStyle(fontSize: 14, height: 1.45, color: isDark ? Colors.white70 : CoachDashboardTheme.textPrimary),
                        ),
                      ),
                    if (_source == 'weekly_plan' && weeklyDays.isNotEmpty)
                      ...weeklyDays.map((day) => _weeklyDaySection(context, day, isDark, title))
                    else if (exercises.isNotEmpty)
                      _Section(
                        isDark: isDark,
                        title: 'Exercises (${exercises.length})',
                        child: Column(
                          children: exercises.map((raw) {
                            final map = raw is Map
                                ? Map<dynamic, dynamic>.from(raw)
                                : <dynamic, dynamic>{'name': raw?.toString() ?? 'Exercise'};
                            return _ExerciseCard(exercise: map, isDark: isDark);
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
              if (_canSubmit && onSubmitProof != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).padding.bottom),
                  child: WorkoutCompleteButton(
                    isLoading: isSubmitting,
                    onPressed: () async {
                      await onSubmitProof!(workout);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _weeklyDaySection(BuildContext context, Map<String, dynamic> day, bool isDark, String planTitle) {
    final dayName = day['dayName']?.toString() ?? 'Workout day';
    final dayExercises = day['exercises'] as List<dynamic>? ?? const [];
    final dayCompletion = day['completion'] is Map
        ? Map<String, dynamic>.from(day['completion'] as Map)
        : <String, dynamic>{};
    final dayStatus = dayCompletion['status']?.toString() ?? 'pending';
    final scheduleId = day['scheduleId']?.toString() ?? '';
    final canSubmit = scheduleId.isNotEmpty && (dayStatus == 'pending' || dayStatus == 'missed');

    return _Section(
      isDark: isDark,
      title: dayName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusChip(status: dayStatus, isDark: isDark),
              if (day['startDateTime'] != null) ...[
                const SizedBox(width: 8),
                Text(
                  formatApiDateTime(day['startDateTime']?.toString()),
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
                ),
              ],
            ],
          ),
          if (dayExercises.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...dayExercises.map((raw) {
              final map = raw is Map
                  ? Map<dynamic, dynamic>.from(raw)
                  : <dynamic, dynamic>{'name': raw?.toString() ?? 'Exercise'};
              return _ExerciseCard(exercise: map, isDark: isDark);
            }),
          ],
          if (canSubmit && onSubmitProof != null) ...[
            const SizedBox(height: 12),
            WorkoutCompleteButton(
              compact: true,
              isLoading: isSubmitting,
              onPressed: () async {
                await onSubmitProof!({
                  '_id': scheduleId,
                  'source': 'schedule',
                  'title': '$planTitle · $dayName',
                });
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
          if (dayCompletion.isNotEmpty &&
              (dayStatus == 'pending_review' ||
                  dayStatus == 'completed' ||
                  dayCompletion['hasProofPhoto'] == true)) ...[
            const SizedBox(height: 12),
            WorkoutCompletionProofView(completion: dayCompletion, isDark: isDark),
          ],
        ],
      ),
    );
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'schedule':
        return 'Scheduled workout';
      case 'weekly_plan':
        return 'Weekly plan';
      default:
        return 'Assigned workout';
    }
  }
}

class _Section extends StatelessWidget {
  final bool isDark;
  final String title;
  final Widget child;

  const _Section({required this.isDark, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: CoachDashboardTheme.sectionTitle(isDark)),
          const SizedBox(height: 8),
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

  const _DetailRow({required this.isDark, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : CoachDashboardTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final bool isDark;

  const _StatusChip({required this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = _color(status);
    return Container(
      margin: const EdgeInsets.only(right: 4, top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _label(status),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Color _color(String status) {
    switch (status) {
      case 'completed':
        return CoachDashboardTheme.success;
      case 'pending_review':
        return CoachDashboardTheme.warning;
      case 'missed':
        return CoachDashboardTheme.danger;
      default:
        return CoachDashboardTheme.primary;
    }
  }

  String _label(String status) {
    switch (status) {
      case 'completed':
        return 'Approved';
      case 'pending_review':
        return 'Pending Review';
      case 'missed':
        return 'Missed';
      default:
        return 'Assigned';
    }
  }
}

class _ExerciseCard extends StatelessWidget {
  final Map<dynamic, dynamic> exercise;
  final bool isDark;

  const _ExerciseCard({required this.exercise, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final name = exercise['name']?.toString() ?? 'Exercise';
    final equipment = exercise['equipment']?.toString().trim() ?? '';
    final instructions = exercise['instructions']?.toString().trim() ?? exercise['notes']?.toString().trim() ?? '';
    final parts = <String>[];
    if (exercise['sets'] != null || exercise['reps'] != null) {
      parts.add('${exercise['sets'] ?? '-'} × ${exercise['reps'] ?? '-'} reps');
    }
    if (exercise['durationMinutes'] != null) parts.add('${exercise['durationMinutes']} min');
    if (exercise['restSeconds'] != null) parts.add('${exercise['restSeconds']}s rest');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12151C) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? Colors.white : CoachDashboardTheme.textPrimary)),
          if (parts.isNotEmpty)
            Text(parts.join(' · '), style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : CoachDashboardTheme.textSecondary)),
          if (equipment.isNotEmpty)
            Text('Equipment: $equipment', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : CoachDashboardTheme.textSecondary)),
          if (instructions.isNotEmpty)
            Text('Instructions: $instructions', style: TextStyle(fontSize: 12, height: 1.35, color: isDark ? Colors.white70 : CoachDashboardTheme.textPrimary)),
          if (WorkoutMediaUrls.normalize(exercise['demoVideoUrl']?.toString()) case final videoUrl?) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => WorkoutMediaUrls.open(context, videoUrl),
              child: Text(
                'Watch demo video',
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

/// Merge workout plans with schedule feed so every coach-assigned workout appears once.
List<Map<String, dynamic>> mergeUserWorkoutSources({
  required List<dynamic> plans,
  Map<String, dynamic>? scheduleData,
}) {
  final merged = plans.map((w) => Map<String, dynamic>.from(w as Map)).toList();
  final seenScheduleIds = <String>{};

  for (final workout in merged) {
    if (workout['source'] == 'schedule') {
      seenScheduleIds.add(workout['_id'].toString());
    }
    if (workout['source'] == 'weekly_plan') {
      for (final raw in workout['days'] as List<dynamic>? ?? const []) {
        if (raw is Map && raw['scheduleId'] != null) {
          seenScheduleIds.add(raw['scheduleId'].toString());
        }
      }
    }
  }

  final allSchedules = scheduleData?['all'] as List<dynamic>? ?? const [];
  for (final raw in allSchedules) {
    if (raw is! Map) continue;
    final schedule = Map<String, dynamic>.from(raw);
    final id = schedule['_id']?.toString() ?? '';
    if (id.isEmpty || seenScheduleIds.contains(id)) continue;

    if (schedule['weeklyPlan'] != null) {
      final weeklyPlanId = schedule['weeklyPlan'] is Map
          ? schedule['weeklyPlan']['_id']?.toString()
          : schedule['weeklyPlan']?.toString();
      final coveredByWeeklyPlan = merged.any(
        (w) => w['source'] == 'weekly_plan' && w['_id']?.toString() == weeklyPlanId,
      );
      if (coveredByWeeklyPlan) continue;
    }

    merged.add(_scheduleToWorkoutItem(schedule));
  }

  merged.sort((a, b) {
    final aTime = _workoutSortTime(a);
    final bTime = _workoutSortTime(b);
    return bTime.compareTo(aTime);
  });

  return merged;
}

Map<String, dynamic> _scheduleToWorkoutItem(Map<String, dynamic> schedule) {
  final template = schedule['workoutTemplate'] is Map
      ? Map<String, dynamic>.from(schedule['workoutTemplate'] as Map)
      : (schedule['workout'] is Map ? Map<String, dynamic>.from(schedule['workout'] as Map) : null);

  final exercises = (schedule['exercises'] as List<dynamic>?)?.isNotEmpty == true
      ? schedule['exercises'] as List<dynamic>
      : (template?['exercises'] as List<dynamic>? ?? const []);

  final completion = schedule['completion'] is Map
      ? Map<String, dynamic>.from(schedule['completion'] as Map)
      : <String, dynamic>{'status': 'pending', 'completable': true};

  if (!completion.containsKey('completable')) {
    final status = completion['status']?.toString() ?? 'pending';
    completion['completable'] = status == 'pending' || status == 'missed';
  }

  return {
    '_id': schedule['_id'],
    'title': schedule['title']?.toString() ?? template?['title']?.toString() ?? 'Workout',
    'description': schedule['notes']?.toString() ?? template?['description']?.toString() ?? '',
    'level': template?['level']?.toString() ?? 'Beginner',
    'exercises': exercises,
    'coach': schedule['coach'],
    'client': schedule['client'],
    'fitnessClass': schedule['fitnessClass'],
    'startDateTime': schedule['startDateTime'],
    'endDateTime': schedule['endDateTime'],
    'durationMinutes': schedule['durationMinutes'],
    'notes': schedule['notes'],
    'createdAt': schedule['createdAt'],
    'updatedAt': schedule['updatedAt'],
    'source': 'schedule',
    'assigneeType': schedule['fitnessClass'] != null ? 'group' : 'user',
    'groupName': schedule['fitnessClass'] is Map ? schedule['fitnessClass']['title'] : null,
    'completion': completion,
  };
}

int _workoutSortTime(Map<String, dynamic> workout) {
  for (final key in ['startDateTime', 'updatedAt', 'createdAt', 'weekStartDate']) {
    final raw = workout[key]?.toString();
    if (raw == null || raw.isEmpty) continue;
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.millisecondsSinceEpoch;
  }
  return 0;
}

String workoutStatusForFilter(Map<String, dynamic> workout) {
  return workout['completion'] is Map
      ? (workout['completion']['status']?.toString() ?? 'pending')
      : 'pending';
}

bool workoutMatchesFilter(Map<String, dynamic> workout, int filterIndex) {
  final status = workoutStatusForFilter(workout);
  switch (filterIndex) {
    case 1:
      return status == 'pending' || status == 'pending_review' || status == 'missed';
    case 2:
      return status == 'completed';
    default:
      return true;
  }
}
