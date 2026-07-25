import 'package:flutter/material.dart';
import 'widgets/coach_home/coach_dashboard_theme.dart';
import '../../../services/api_service.dart';
import '../../../utils/share_helpers.dart';
import '../../../utils/workout_media_urls.dart';

class AssignmentsScreen extends StatefulWidget {
  final Map<String, dynamic> coachingData;

  const AssignmentsScreen({super.key, required this.coachingData});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSubmitting = false;
  String _error = '';
  List<dynamic> _workouts = [];
  Map<String, dynamic>? _progress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    } else {
      setState(() {
        _isRefreshing = true;
        _error = '';
      });
    }
    try {
      final results = await Future.wait([
        _apiService.getUserExercisePlans(),
        _apiService.getUserWorkoutProgress(),
      ]);
      if (mounted) {
        setState(() {
          _workouts = List<dynamic>.from(results[0] as List);
          _progress = results[1] as Map<String, dynamic>;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiService.friendlyError(e);
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _completeWorkout(Map<String, dynamic> plan) async {
    final planId = plan['_id']?.toString() ?? '';
    final title = plan['title'] as String? ?? 'Workout';
    final source = plan['source']?.toString() ?? 'exercise_plan';
    if (planId.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      if (source == 'schedule') {
        await _apiService.completeWorkoutSchedule(planId);
      } else {
        await _apiService.completeWorkout(planId);
      }
      await _load(isRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Workout marked as completed!'),
          backgroundColor: CoachDashboardTheme.success,
        ));
        await offerShareWorkoutWin(context, workoutTitle: title);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ApiService.friendlyError(e)),
          backgroundColor: CoachDashboardTheme.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coachName = widget.coachingData['coach']?['name'] as String? ?? 'Your Coach';
    final articles = (widget.coachingData['assignedArticles'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((a) => Map<String, dynamic>.from(a))
        .toList();
    final summary = _progress?['summary'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      appBar: CoachDashboardTheme.coachAppBar(
        context: context,
        title: 'My Workouts',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: (_isLoading || _isRefreshing) ? null : () => _load(isRefresh: true),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: CoachDashboardTheme.primary))
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: CoachDashboardTheme.danger)))
              : RefreshIndicator(
                  onRefresh: () => _load(isRefresh: true),
                  color: CoachDashboardTheme.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: CoachDashboardTheme.headerGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: CoachDashboardTheme.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.fitness_center_rounded, color: Colors.white, size: 32),
                          const SizedBox(height: 12),
                          const Text('Your Workouts', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('Assigned by $coachName', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                          if (summary != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              '${summary['completionPercent'] ?? 0}% complete · ${summary['completed'] ?? 0} done · ${summary['pending'] ?? 0} pending',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                            ),
                          ],
                        ]),
                      ),
                      const SizedBox(height: 24),
                      if (_workouts.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: CoachDashboardTheme.cardDecoration(isDark),
                          child: const Center(child: Text('No workouts assigned yet.', style: TextStyle(color: Colors.grey))),
                        )
                      else
                        ..._workouts.map((w) => _buildWorkoutCard(w as Map<String, dynamic>, isDark)),
                      const SizedBox(height: 32),
                      const Text('Coach Resources', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 12),
                      if (articles.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: CoachDashboardTheme.cardDecoration(isDark),
                          child: const Center(child: Text('No resources assigned right now.', style: TextStyle(color: Colors.grey))),
                        )
                      else
                        ...articles.map((a) => _buildArticleCard(a, isDark)),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> plan, bool isDark) {
    final title = plan['title'] as String? ?? 'Workout';
    final level = plan['level'] as String? ?? 'Beginner';
    final description = plan['description'] as String? ?? '';
    final exercises = plan['exercises'] as List<dynamic>? ?? [];
    final completion = plan['completion'] as Map<String, dynamic>? ?? {};
    final status = completion['status'] as String? ?? 'pending';
    final source = plan['source']?.toString() ?? 'exercise_plan';
    final assigneeType = plan['assigneeType']?.toString() ?? 'user';
    final groupName = plan['groupName']?.toString();
    final weeklyDays = (plan['days'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((day) => Map<String, dynamic>.from(day))
        .where((day) => day['enabled'] == true && day['offDay'] != true)
        .toList();
    final isPending = status == 'pending';
    final isCompleted = status == 'completed';
    final canComplete = source != 'weekly_plan' &&
        (completion['completable'] != false) &&
        isPending;

    final subtitleParts = <String>[
      level,
      if (assigneeType == 'group')
        (groupName != null && groupName.isNotEmpty) ? 'Group · $groupName' : 'Group',
      if (source == 'weekly_plan') 'Weekly plan',
      if (source == 'schedule') 'Scheduled',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canComplete || isCompleted)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: _isSubmitting && canComplete
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: CoachDashboardTheme.primary),
                        )
                      : Checkbox(
                          value: isCompleted,
                          activeColor: CoachDashboardTheme.success,
                          onChanged: canComplete && !_isSubmitting
                              ? (_) => _completeWorkout(plan)
                              : null,
                        ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                        _statusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleParts.join(' · '),
                      style: const TextStyle(color: CoachDashboardTheme.primary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(description, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade700)),
          ],
          if (source == 'weekly_plan') ...[
            const SizedBox(height: 6),
            Text(
              'Tick each workout day after you complete it.',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            ...weeklyDays.map((day) {
              final scheduleId = day['scheduleId']?.toString() ?? '';
              final dayName = day['dayName']?.toString() ?? 'Workout day';
              final dayCompletion = day['completion'] is Map
                  ? Map<String, dynamic>.from(day['completion'] as Map)
                  : <String, dynamic>{};
              final dayStatus = dayCompletion['status']?.toString() ?? 'pending';
              final completed = dayStatus == 'completed';
              final missed = dayStatus == 'missed';
              final canMark = scheduleId.isNotEmpty && dayStatus != 'completed' && !_isSubmitting;
              final dayExercises = day['exercises'] as List<dynamic>? ?? const [];

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: completed
                        ? CoachDashboardTheme.success.withValues(alpha: 0.35)
                        : (isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: completed,
                      activeColor: CoachDashboardTheme.success,
                      visualDensity: VisualDensity.compact,
                      onChanged: canMark
                          ? (_) => _completeWorkout({
                                '_id': scheduleId,
                                'source': 'schedule',
                                'title': '$title · $dayName',
                              })
                          : null,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text(
                            '${dayExercises.length} exercise${dayExercises.length == 1 ? '' : 's'} · '
                            '${completed ? 'Completed' : (missed ? 'Missed' : 'Pending')}',
                            style: TextStyle(
                              fontSize: 11,
                              color: completed
                                  ? CoachDashboardTheme.success
                                  : (missed ? CoachDashboardTheme.danger : Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 10),
          if (exercises.isEmpty)
            Text(
              'No exercises listed yet.',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey),
            )
          else
            ...exercises.map((ex) {
              final map = ex is Map
                  ? Map<dynamic, dynamic>.from(ex)
                  : <dynamic, dynamic>{'name': ex?.toString() ?? 'Exercise'};
              final dayName = map['dayName']?.toString();
              if (dayName != null && dayName.isNotEmpty && map['name'] != null) {
                map['name'] = '$dayName · ${map['name']}';
              }
              return WorkoutExerciseRow(exercise: map, isDark: isDark);
            }),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'completed':
        color = CoachDashboardTheme.success;
        label = 'Completed';
        break;
      case 'missed':
        color = CoachDashboardTheme.danger;
        label = 'Missed';
        break;
      default:
        color = Colors.orange;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildArticleCard(Map<String, dynamic> a, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: CoachDashboardTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.article_rounded, color: CoachDashboardTheme.primary),
        ),
        title: Text(a['title'] as String? ?? 'Document', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Read assigned resource', style: TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
        onTap: () {
          final body = (a['body'] ?? a['summary'] ?? '').toString().trim();
          final title = (a['title'] ?? 'Resource').toString();
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: isDark ? const Color(0xFF1A1D27) : Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (ctx) => Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.of(ctx).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(
                      body.isEmpty ? 'No content available for this resource.' : body,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
