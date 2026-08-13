import 'package:flutter/material.dart';
import 'widgets/coach_home/coach_dashboard_theme.dart';
import '../../../services/api_service.dart';
import '../../../utils/date_utils.dart';
import '../../../widgets/user_workout_detail_sheet.dart';
import '../../../widgets/workout_proof_sheet.dart';
import '../../../widgets/workout_completion_proof_view.dart';
import '../../../widgets/workout_mark_complete_control.dart';
import '../../widgets/silent_refresh.dart';

class AssignmentsScreen extends StatefulWidget {
  final Map<String, dynamic>? coachingData;
  final VoidCallback? onDataChanged;

  const AssignmentsScreen({super.key, this.coachingData, this.onDataChanged});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late final TabController _filterTab;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSubmitting = false;
  String _error = '';
  List<Map<String, dynamic>> _workouts = [];
  Map<String, dynamic>? _progress;

  @override
  void initState() {
    super.initState();
    _filterTab = TabController(length: 3, vsync: this);
    _filterTab.addListener(() {
      if (!_filterTab.indexIsChanging) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _filterTab.dispose();
    super.dispose();
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
        _apiService.getUserExercisePlans().catchError((_) => <dynamic>[]),
        _apiService.getUserWorkoutProgress().catchError((_) => <String, dynamic>{}),
        _apiService.getUserWorkoutSchedules().catchError((_) => <String, dynamic>{}),
      ]).timeout(const Duration(seconds: 35), onTimeout: () {
        throw Exception('Unable to load workouts. Please retry.');
      });
      if (mounted) {
        final plans = List<dynamic>.from(results[0] as List);
        final scheduleData = results[2] as Map<String, dynamic>?;
        final progress = Map<String, dynamic>.from(results[1] as Map? ?? {});
        final history = (progress['history'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((h) => Map<String, dynamic>.from(h))
            .toList();
        final merged = mergeUserWorkoutSources(plans: plans, scheduleData: scheduleData);
        enrichWorkoutsWithHistoryProof(merged, history);
        setState(() {
          _workouts = merged;
          _progress = progress;
          if (plans.isEmpty && progress.isEmpty && (scheduleData == null || scheduleData.isEmpty)) {
            _error = '';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiService.friendlyError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
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

    final proof = await showWorkoutProofSheet(context, workoutTitle: title);
    if (proof == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      if (source == 'schedule') {
        await _apiService.completeWorkoutSchedule(
          planId,
          notes: proof['notes'] as String,
          durationMinutes: proof['durationMinutes'] as int,
          proofPhoto: proof['proofPhoto'] as String,
        );
      } else {
        await _apiService.completeWorkout(
          planId,
          notes: proof['notes'] as String,
          durationMinutes: proof['durationMinutes'] as int,
          proofPhoto: proof['proofPhoto'] as String,
        );
      }
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _workouts = _workouts.map((w) {
            if (w['_id']?.toString() != planId) return w;
            final copy = Map<String, dynamic>.from(w as Map);
            copy['status'] = 'pending_review';
            copy['completion'] = {
              ...(copy['completion'] is Map
                  ? Map<String, dynamic>.from(copy['completion'] as Map)
                  : <String, dynamic>{}),
              'status': 'pending_review',
            };
            return copy;
          }).toList();
        });
        final streak = (_progress?['summary'] as Map<String, dynamic>?)?['streak'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Submitted for coach review · Streak updates on approval (current: $streak days)',
          ),
          backgroundColor: CoachDashboardTheme.warning,
        ));
      }
      // Refresh in background — do not hold the button spinner.
      _load(isRefresh: true);
      widget.onDataChanged?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ApiService.friendlyError(e)),
          backgroundColor: CoachDashboardTheme.danger,
        ));
      }
    } finally {
      if (mounted && _isSubmitting) setState(() => _isSubmitting = false);
    }
  }

  String get _coachName {
    final fromCoaching = widget.coachingData?['coach']?['name'] as String?;
    if (fromCoaching != null && fromCoaching.isNotEmpty) return fromCoaching;
    for (final workout in _workouts) {
      if (workout['coach'] is Map) {
        final name = ApiService.displayName(
          Map<dynamic, dynamic>.from(workout['coach'] as Map),
          fallback: '',
        );
        if (name.isNotEmpty) return name;
      }
    }
    return 'Your coach';
  }

  List<Map<String, dynamic>> get _filteredWorkouts =>
      _workouts.where((w) => workoutMatchesFilter(w, _filterTab.index)).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final articles = (widget.coachingData?['assignedArticles'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((a) => Map<String, dynamic>.from(a))
        .toList();
    final summary = _progress?['summary'] as Map<String, dynamic>?;
    final history = (_progress?['history'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((h) => Map<String, dynamic>.from(h))
        .toList();
    final recentHistory = history.take(8).toList();

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      appBar: CoachDashboardTheme.coachAppBar(
        context: context,
        title: 'My Workouts',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: (_isLoading || _isRefreshing) ? null : () => _load(isRefresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: CoachDashboardTheme.danger)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: () => _load(), child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SilentRefreshIndicator(
                        onRefresh: () => _load(isRefresh: true),
                        color: CoachDashboardTheme.primary,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                                child: _headerCard(summary, isDark),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                                child: Row(
                                  children: [
                                    Text(
                                      '${_workouts.length} assigned',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: TabBar(
                                controller: _filterTab,
                                labelColor: CoachDashboardTheme.primary,
                                unselectedLabelColor: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
                                indicatorColor: CoachDashboardTheme.primary,
                                onTap: (_) => setState(() {}),
                                tabs: const [
                                  Tab(text: 'All'),
                                  Tab(text: 'Active'),
                                  Tab(text: 'Completed'),
                                ],
                              ),
                            ),
                            if (_filteredWorkouts.isEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: CoachDashboardTheme.emptyState(
                                    icon: Icons.fitness_center_outlined,
                                    title: _filterTab.index == 0 ? 'No workouts yet' : 'Nothing here',
                                    message: _filterTab.index == 0
                                        ? 'Workouts assigned by your coach will appear here automatically.'
                                        : 'Try another filter to see more workouts.',
                                    isDark: isDark,
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _buildWorkoutCard(_filteredWorkouts[index], isDark),
                                    childCount: _filteredWorkouts.length,
                                  ),
                                ),
                              ),
                            if (recentHistory.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                                  child: Text(
                                    'Recent activity',
                                    style: CoachDashboardTheme.sectionTitle(isDark),
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _buildHistoryRow(recentHistory[index], isDark),
                                    childCount: recentHistory.length,
                                  ),
                                ),
                              ),
                            ],
                            if (articles.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                                  child: Text(
                                    'Coach resources',
                                    style: CoachDashboardTheme.sectionTitle(isDark),
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _buildArticleCard(articles[index], isDark),
                                    childCount: articles.length,
                                  ),
                                ),
                              ),
                            ] else
                              const SliverToBoxAdapter(child: SizedBox(height: 100)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _headerCard(Map<String, dynamic>? summary, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: CoachDashboardTheme.headerGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CoachDashboardTheme.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.fitness_center_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          const Text('My Workouts', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Assigned by $_coachName',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
          ),
          if (summary != null) ...[
            const SizedBox(height: 12),
            Text(
              '${summary['completionPercent'] ?? 0}% approved · '
              '${summary['completed'] ?? 0} done · '
              '${summary['pendingReview'] ?? 0} in review · '
              '${summary['pending'] ?? 0} assigned · '
              'streak ${summary['streak'] ?? 0}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> plan, bool isDark) {
    final title = plan['title'] as String? ?? 'Workout';
    final level = plan['level'] as String? ?? 'Beginner';
    final description = plan['description'] as String? ?? '';
    final exercises = plan['exercises'] as List<dynamic>? ?? [];
    final completion = plan['completion'] as Map<String, dynamic>? ?? {};
    final status = workoutStatusForFilter(plan);
    final source = plan['source']?.toString() ?? 'exercise_plan';
    final assigneeType = plan['assigneeType']?.toString() ?? 'user';
    final groupName = plan['groupName']?.toString();
    final canComplete = source != 'weekly_plan' &&
        (completion['completable'] != false) &&
        (status == 'pending' || status == 'missed');
    final showProof = status == 'pending_review' ||
        status == 'completed' ||
        completion['hasProofPhoto'] == true ||
        (completion['notes']?.toString().trim().isNotEmpty ?? false);

    final subtitleParts = <String>[
      level,
      _sourceShortLabel(source),
      if (assigneeType == 'group' && groupName != null && groupName.isNotEmpty) groupName,
      if (source == 'schedule' && plan['startDateTime'] != null)
        formatApiDateTime(plan['startDateTime']?.toString()),
    ];

    final weeklyDays = (plan['days'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((d) => Map<String, dynamic>.from(d))
        .where((d) => d['enabled'] == true && d['offDay'] != true)
        .toList();
    final completedDays = weeklyDays.where((d) {
      final dayStatus = d['completion'] is Map ? d['completion']['status']?.toString() : null;
      return dayStatus == 'completed' || dayStatus == 'pending_review';
    }).length;

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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: CoachDashboardTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center_rounded, color: CoachDashboardTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        _statusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleParts.join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade700),
            ),
          ],
          if (showProof) ...[
            const SizedBox(height: 12),
            WorkoutCompletionProofView(
              completion: completion,
              isDark: isDark,
              title: 'Your submission',
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _metaChip(
                isDark,
                source == 'weekly_plan'
                    ? '$completedDays / ${weeklyDays.length} days'
                    : '${exercises.length} exercise${exercises.length == 1 ? '' : 's'}',
              ),
              if (plan['coach'] is Map)
                _metaChip(
                  isDark,
                  ApiService.displayName(
                    Map<dynamic, dynamic>.from(plan['coach'] as Map),
                    fallback: 'Coach',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => showUserWorkoutDetailSheet(
                  context,
                  workout: plan,
                  onSubmitProof: _completeWorkout,
                  isSubmitting: _isSubmitting,
                ),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('View details'),
              ),
              if (canComplete)
                WorkoutCompleteButton(
                  compact: true,
                  isLoading: _isSubmitting,
                  onPressed: () => _completeWorkout(plan),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(bool isDark, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : CoachDashboardTheme.textSecondary),
      ),
    );
  }

  String _sourceShortLabel(String source) {
    switch (source) {
      case 'schedule':
        return 'Scheduled';
      case 'weekly_plan':
        return 'Weekly plan';
      default:
        return 'Assigned';
    }
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'completed':
        color = CoachDashboardTheme.success;
        label = 'Approved';
        break;
      case 'pending_review':
        color = CoachDashboardTheme.warning;
        label = 'In Review';
        break;
      case 'missed':
        color = CoachDashboardTheme.danger;
        label = 'Missed';
        break;
      default:
        color = CoachDashboardTheme.primary;
        label = 'Assigned';
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

  Widget _buildHistoryRow(Map<String, dynamic> item, bool isDark) {
    final status = item['status']?.toString() ?? 'pending';
    final title = item['exercisePlan'] is Map
        ? (item['exercisePlan']['title']?.toString() ?? 'Workout')
        : (item['workoutSchedule'] is Map
            ? ((item['workoutSchedule']['workoutTemplate'] is Map
                    ? item['workoutSchedule']['workoutTemplate']['title']
                    : null)
                ?.toString() ??
                'Workout')
            : 'Workout');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 8),
          WorkoutCompletionProofView(completion: item, isDark: isDark),
        ],
      ),
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
          decoration: BoxDecoration(
            color: CoachDashboardTheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
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
