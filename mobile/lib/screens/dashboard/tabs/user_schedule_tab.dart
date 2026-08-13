import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/api_service.dart';
import '../../../widgets/scrollable_body.dart';
import '../../../widgets/tab_refresh.dart';
import '../../../widgets/animations/animations.dart';
import '../../../utils/date_utils.dart';
import '../../../utils/workout_media_urls.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';
import '../../../widgets/workout_proof_sheet.dart';
import '../../../widgets/workout_completion_proof_view.dart';
import '../../../widgets/workout_mark_complete_control.dart';
import 'user_classes_tab.dart';

class UserScheduleTab extends StatefulWidget {
  final User user;
  final VoidCallback? onScheduleDataChanged;
  final DateTime? initialWeekStart;

  const UserScheduleTab({
    super.key,
    required this.user,
    this.onScheduleDataChanged,
    this.initialWeekStart,
  });

  @override
  State<UserScheduleTab> createState() => UserScheduleTabState();
}

class UserScheduleTabState extends State<UserScheduleTab> with SingleTickerProviderStateMixin, TabRefreshMixin {
  final ApiService _apiService = ApiService();
  final GlobalKey<UserClassesTabState> _classesTabKey = GlobalKey<UserClassesTabState>();
  late TabController _tabCtrl;

  List<dynamic> _today = [];
  List<dynamic> _upcoming = [];
  List<dynamic> _history = [];
  Map<String, dynamic> _weeklyData = {};
  DateTime _weekStart = mondayOf(DateTime.now());
  bool _completing = false;
  int _loadSeq = 0;
  int _dataVersion = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    if (widget.initialWeekStart != null) {
      _weekStart = mondayOf(widget.initialWeekStart!);
    }
    _load(respectSelectedWeek: widget.initialWeekStart != null);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> refresh({bool preserveWeek = false}) =>
      _refreshAll(preserveWeek: preserveWeek, showFeedback: false);

  Future<void> _refreshAll({bool preserveWeek = true, bool showFeedback = false}) async {
    try {
      await _load(isRefresh: true, respectSelectedWeek: preserveWeek);
      await (_classesTabKey.currentState?.refresh(isRefresh: true) ?? Future.value());
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule updated'),
            backgroundColor: CoachDashboardTheme.success,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      // finishTabError in _load already surfaces API failures.
    }
  }

  /// Opens the coach schedule view, optionally jumping to a specific week.
  void openCoachSchedule({DateTime? weekStart}) {
    if (weekStart != null) {
      setState(() => _weekStart = mondayOf(weekStart));
    }
    _tabCtrl.index = 0;
    _load(isRefresh: true, respectSelectedWeek: weekStart != null);
  }

  Future<void> _load({bool isRefresh = false, bool respectSelectedWeek = false}) async {
    final seq = ++_loadSeq;
    beginTabLoad(isRefresh: isRefresh);
    try {
      final scheduleData = await _apiService
          .getUserWorkoutSchedules(bustCache: isRefresh)
          .timeout(const Duration(seconds: 20));
      if (!mounted || seq != _loadSeq) return;

      var weekToLoad = respectSelectedWeek ? mondayOf(_weekStart) : _resolveBestWeek(scheduleData);

      var weeklyData = await _apiService
          .getUserWeeklySchedule(
            weekStart: weekToLoad,
            bustCache: isRefresh,
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted || seq != _loadSeq) return;

      final workoutDays = (weeklyData['summary'] as Map<String, dynamic>?)?['workoutDays'] as int? ?? 0;

      if (!respectSelectedWeek && workoutDays == 0) {
        final upcoming = List<dynamic>.from(scheduleData['upcoming'] as List<dynamic>? ?? []);
        if (upcoming.isNotEmpty) {
          final firstStart = parseApiDateTime(upcoming.first['startDateTime']?.toString());
          if (firstStart != null) {
            final targetWeek = mondayOf(firstStart);
            if (targetWeek != weekToLoad) {
              weekToLoad = targetWeek;
              weeklyData = await _apiService
                  .getUserWeeklySchedule(
                    weekStart: weekToLoad,
                    bustCache: isRefresh,
                  )
                  .timeout(const Duration(seconds: 15));
              if (!mounted || seq != _loadSeq) return;
            }
          }
        }
      }

      finishTabLoad(() {
        final data = Map<String, dynamic>.from(scheduleData);
        _today = _filterTodayTasks(List<dynamic>.from(data['today'] as List<dynamic>? ?? []));
        _upcoming = List<dynamic>.from(data['upcoming'] as List<dynamic>? ?? []);
        _history = List<dynamic>.from(data['history'] as List<dynamic>? ?? []);
        _weeklyData = _cloneWeeklyData(weeklyData);
        _dataVersion++;
        final apiWeek = parseApiDateOnly(_weeklyData['weekStart']?.toString());
        if (apiWeek != null) _weekStart = mondayOf(apiWeek);
      });
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      finishTabError(e, isRefresh: isRefresh);
    } finally {
      // Stale responses must not clear a newer in-flight load.
      if (mounted && seq == _loadSeq && (tabIsLoading || tabIsRefreshing)) {
        setState(() {
          tabIsLoading = false;
          tabIsRefreshing = false;
        });
      }
    }
  }

  Map<String, dynamic> _cloneWeeklyData(Map<String, dynamic> weeklyData) {
    final cloned = Map<String, dynamic>.from(weeklyData);
    final days = weeklyData['days'];
    if (days is List) {
      cloned['days'] = days
          .map((d) => d is Map ? Map<String, dynamic>.from(d) : d)
          .toList();
    }
    final summary = weeklyData['summary'];
    if (summary is Map) {
      cloned['summary'] = Map<String, dynamic>.from(summary);
    }
    return cloned;
  }

  /// Picks the most relevant week: today → upcoming → active plan → current week.
  DateTime _resolveBestWeek(Map<String, dynamic> scheduleData) {
    final currentMonday = mondayOf(DateTime.now());

    final today = List<dynamic>.from(scheduleData['today'] as List<dynamic>? ?? []);
    if (today.isNotEmpty) return currentMonday;

    final upcoming = List<dynamic>.from(scheduleData['upcoming'] as List<dynamic>? ?? []);
    if (upcoming.isNotEmpty) {
      final firstStart = parseApiDateTime(upcoming.first['startDateTime']?.toString());
      if (firstStart != null) return mondayOf(firstStart);
    }

    final suggested = parseApiDateOnly(scheduleData['suggestedWeekStart']?.toString());
    if (suggested != null) return mondayOf(suggested);

    return currentMonday;
  }

  List<dynamic> _filterTodayTasks(List<dynamic> items) {
    final today = dateOnly(DateTime.now());
    return items.where((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      final start = parseApiDateTime(item['startDateTime']?.toString());
      if (start == null) return false;
      if (dateOnly(start) != today) return false;
      final status = item['completion']?['status'] as String? ?? 'pending';
      return status == 'pending';
    }).toList();
  }

  Future<void> _complete(String scheduleId, {String title = 'Workout'}) async {
    final proof = await showWorkoutProofSheet(context, workoutTitle: title);
    if (proof == null || !mounted) return;

    setState(() => _completing = true);
    try {
      await _apiService.completeWorkoutSchedule(
        scheduleId,
        notes: proof['notes'] as String,
        durationMinutes: proof['durationMinutes'] as int,
        proofPhoto: proof['proofPhoto'] as String,
      );
      if (mounted) {
        setState(() => _completing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Submitted for coach review · Streak updates when your coach approves'),
            backgroundColor: CoachDashboardTheme.warning,
          ),
        );
      }
      _load(isRefresh: true, respectSelectedWeek: true);
      widget.onScheduleDataChanged?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _completing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: CoachDashboardTheme.danger),
        );
      }
    } finally {
      if (mounted && _completing) setState(() => _completing = false);
    }
  }

  void _showDetail(Map<String, dynamic> item) {
    final workout = item['workoutTemplate'] as Map<String, dynamic>? ?? item['workout'] as Map<String, dynamic>? ?? {};
    final scheduleExercises = item['exercises'] as List<dynamic>? ?? [];
    final templateExercises = workout['exercises'] as List<dynamic>? ?? [];
    final exercises = scheduleExercises.isNotEmpty ? scheduleExercises : templateExercises;
    final workoutTitle = item['title']?.toString() ?? workout['title']?.toString() ?? 'Workout';
    final dayNames = const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayOfWeek = item['dayOfWeek'] as int?;
    final dayLabel = (dayOfWeek != null && dayOfWeek >= 0 && dayOfWeek <= 6) ? dayNames[dayOfWeek] : null;
    final completion = item['completion'] as Map<String, dynamic>? ?? {};
    final status = completion['status'] as String? ?? 'pending';
    final scheduleId = item['_id']?.toString() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF181B24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workoutTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(formatApiDateTime(item['startDateTime']?.toString()), style: const TextStyle(color: CoachDashboardTheme.primary)),
            if (dayLabel != null) ...[
              const SizedBox(height: 4),
              Text('Day: $dayLabel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.grey.shade800)),
            ],
            if (item['coach']?['name'] != null) ...[
              const SizedBox(height: 4),
              Text('Coach: ${item['coach']['name']}', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade700)),
            ],
            if (item['weeklyPlan'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'From weekly plan: ${item['weeklyPlan']['title'] ?? 'Weekly Plan'}',
                style: const TextStyle(fontSize: 12, color: CoachDashboardTheme.primary),
              ),
            ],
            if ((item['notes'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Coach notes', style: CoachDashboardTheme.sectionTitle(isDark)),
              Text(item['notes'].toString()),
            ],
            if ((workout['description'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(workout['description'].toString(), style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700)),
            ],
            const SizedBox(height: 16),
            Text(
              dayLabel != null ? '$workoutTitle → $dayLabel → Exercises' : 'Exercises',
              style: CoachDashboardTheme.sectionTitle(isDark),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: exercises.isEmpty
                      ? [
                          Text('No exercises listed.', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                        ]
                      : exercises.map((ex) {
                          final map = ex is Map
                              ? Map<dynamic, dynamic>.from(ex)
                              : <dynamic, dynamic>{'name': ex?.toString() ?? 'Exercise'};
                          return WorkoutExerciseRow(exercise: map, isDark: isDark);
                        }).toList(),
                ),
              ),
            ),
            if (status == 'pending' || status == 'missed') ...[
              const SizedBox(height: 16),
              WorkoutCompleteButton(
                isLoading: _completing,
                onPressed: _completing
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _complete(scheduleId, title: workoutTitle);
                      },
              ),
            ],
            if (status == 'pending_review') ...[
              const SizedBox(height: 12),
              Text(
                'Pending coach review',
                style: TextStyle(color: CoachDashboardTheme.warning, fontWeight: FontWeight.w600),
              ),
            ],
            if (completion.isNotEmpty &&
                (status == 'pending_review' ||
                    status == 'completed' ||
                    completion['hasProofPhoto'] == true ||
                    (completion['notes']?.toString().trim().isNotEmpty ?? false))) ...[
              const SizedBox(height: 12),
              WorkoutCompletionProofView(completion: completion, isDark: isDark, title: 'Your submission'),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: CoachDashboardTheme.headerGradient,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (Navigator.canPop(context))
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: IconButton(
                            tooltip: 'Back',
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          ),
                        ),
                      const Expanded(
                        child: Text('Schedule', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: (showInitialLoading || tabIsRefreshing)
                            ? null
                            : () => _refreshAll(preserveWeek: true, showFeedback: true),
                        icon: tabRefreshIcon(color: Colors.white.withValues(alpha: 0.9)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _upcoming.isNotEmpty || _today.isNotEmpty
                        ? '${_today.length} today · ${_upcoming.length} upcoming from your coach'
                        : 'View workouts your coach has scheduled for you',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: TabBar(
                      controller: _tabCtrl,
                      indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: CoachDashboardTheme.primary,
                      unselectedLabelColor: Colors.white,
                      dividerColor: Colors.transparent,
                      tabs: const [Tab(text: '  Workouts  '), Tab(text: '  Classes  ')],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            showInitialError
                    ? ScrollableCenter(child: Text(tabLoadError!, style: const TextStyle(color: CoachDashboardTheme.danger)))
                    : PremiumRefreshIndicator(
                        onRefresh: () => _refreshAll(preserveWeek: true, showFeedback: true),
                        child: ListView(
                          physics: dashboardScrollPhysics,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: MediaQuery.sizeOf(context).height - 280,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                            _WeeklyGrid(
                              key: ValueKey('weekly-$_dataVersion-${_weekStart.toIso8601String()}'),
                              data: _weeklyData,
                              isDark: isDark,
                              weekStart: _weekStart,
                              completing: _completing,
                              onPrevWeek: () {
                                setState(() => _weekStart = mondayOf(_weekStart.subtract(const Duration(days: 7))));
                                _load(isRefresh: true, respectSelectedWeek: true);
                              },
                              onNextWeek: () {
                                setState(() => _weekStart = mondayOf(_weekStart.add(const Duration(days: 7))));
                                _load(isRefresh: true, respectSelectedWeek: true);
                              },
                              onJumpToCurrentWeek: () {
                                setState(() => _weekStart = mondayOf(DateTime.now()));
                                _load(isRefresh: true, respectSelectedWeek: false);
                              },
                              onDayTap: (day) {
                                final schedule = day['schedule'] as Map<String, dynamic>?;
                                if (schedule != null) _showDetail(schedule);
                              },
                              onCompleteWorkout: _complete,
                            ),
                            const SizedBox(height: 16),
                            if (_today.isNotEmpty) ...[
                              Text("Today's Workouts", style: CoachDashboardTheme.sectionTitle(isDark)),
                              const SizedBox(height: 8),
                              ..._today.map((s) => _ScheduleCard(
                                    item: s as Map<String, dynamic>,
                                    isDark: isDark,
                                    highlight: true,
                                    isCompleting: _completing,
                                    onTap: () => _showDetail(Map<String, dynamic>.from(s as Map)),
                                    onComplete: () => _complete((s as Map)['_id'].toString()),
                                  )),
                              const SizedBox(height: 20),
                            ],
                            Text('Upcoming', style: CoachDashboardTheme.sectionTitle(isDark)),
                            const SizedBox(height: 8),
                            if (_upcoming.isEmpty && _today.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Icon(Icons.calendar_month_outlined, size: 40, color: isDark ? Colors.white24 : Colors.grey.shade400),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No workouts scheduled yet',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Workouts assigned by your coach will appear here.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.white54 : Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ..._upcoming.where((s) => !_today.any((t) => t['_id'] == s['_id'])).map((s) => _ScheduleCard(
                                    item: s as Map<String, dynamic>,
                                    isDark: isDark,
                                    isCompleting: _completing,
                                    onTap: () => _showDetail(Map<String, dynamic>.from(s as Map)),
                                    onComplete: () => _complete((s as Map)['_id'].toString()),
                                  )),
                            const SizedBox(height: 20),
                            Text('History', style: CoachDashboardTheme.sectionTitle(isDark)),
                            const SizedBox(height: 8),
                            if (_history.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                child: Center(
                                  child: Text(
                                    'No workout history yet.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              ..._history.map((s) => _ScheduleCard(
                                    item: s as Map<String, dynamic>,
                                    isDark: isDark,
                                    isCompleting: _completing,
                                    onTap: () => _showDetail(Map<String, dynamic>.from(s as Map)),
                                  )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
            UserClassesTab(
              key: _classesTabKey,
              user: widget.user,
              embedded: true,
              onViewWorkoutSchedule: () => _tabCtrl.animateTo(0),
              onScheduleDataChanged: widget.onScheduleDataChanged,
              onParentRefresh: () => _load(isRefresh: true, respectSelectedWeek: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDark;
  final bool highlight;
  final bool isCompleting;
  final VoidCallback onTap;
  final VoidCallback? onComplete;

  const _ScheduleCard({
    required this.item,
    required this.isDark,
    this.highlight = false,
    this.isCompleting = false,
    required this.onTap,
    this.onComplete,
  });

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Approved';
      case 'pending_review':
        return 'Pending Review';
      case 'missed':
        return 'Missed';
      case 'pending':
        return 'Assigned';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = item['title'] as String? ?? item['workoutTemplate']?['title'] as String? ?? 'Workout';
    final start = parseApiDateTime(item['startDateTime']?.toString());
    final coach = item['coach']?['name'] as String? ?? 'Coach';
    final weeklyPlan = item['weeklyPlan'] as Map<String, dynamic>?;
    final isGroup = item['fitnessClass'] != null;
    final groupTitle = item['fitnessClass']?['title'] as String?;
    final status = item['completion']?['status'] as String? ?? 'pending';
    final canComplete = status == 'pending' || status == 'missed';
    final timeStr = start != null
        ? '${start.month}/${start.day} · ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'
        : '';

    Color statusColor;
    switch (status) {
      case 'completed':
        statusColor = CoachDashboardTheme.success;
        break;
      case 'pending_review':
        statusColor = CoachDashboardTheme.warning;
        break;
      case 'missed':
        statusColor = CoachDashboardTheme.danger;
        break;
      default:
        statusColor = Colors.orange;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlight ? CoachDashboardTheme.primary.withValues(alpha: isDark ? 0.12 : 0.08) : (isDark ? const Color(0xFF181B24) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: highlight ? CoachDashboardTheme.primary.withValues(alpha: 0.3) : (isDark ? Colors.white10 : Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            if (onComplete != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: WorkoutMarkCompleteControl(
                  status: status,
                  isLoading: isCompleting && canComplete,
                  onMarkComplete: canComplete && !isCompleting ? onComplete : null,
                ),
              ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: CoachDashboardTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.fitness_center_rounded, color: CoachDashboardTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                      if (weeklyPlan != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: CoachDashboardTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Weekly', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: CoachDashboardTheme.primary)),
                        ),
                    ],
                  ),
                  Text(timeStr, style: const TextStyle(fontSize: 12, color: CoachDashboardTheme.primary)),
                  Text('Coach: $coach', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey)),
                  if (isGroup && groupTitle != null)
                    Text('Group: $groupTitle', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade600)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(_statusLabel(status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
            ),
          ],
        ),
      ),
    );
  }
}


class _WeeklyGrid extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  final DateTime weekStart;
  final bool completing;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onJumpToCurrentWeek;
  final void Function(Map<String, dynamic> day) onDayTap;
  final Future<void> Function(String scheduleId)? onCompleteWorkout;

  const _WeeklyGrid({
    super.key,
    required this.data,
    required this.isDark,
    required this.weekStart,
    this.completing = false,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.onJumpToCurrentWeek,
    required this.onDayTap,
    this.onCompleteWorkout,
  });

  String _formatTime(String? raw) => formatApiTime(raw);

  @override
  Widget build(BuildContext context) {
    final days = data['days'] as List<dynamic>? ?? [];
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekLabel = formatWeekRange(weekStart);
    final currentMonday = mondayOf(DateTime.now());
    final isCurrentWeek = dateOnly(weekStart) == dateOnly(currentMonday);

    final dayRows = days.isEmpty
        ? List.generate(7, (i) => {
              'dayOfWeek': i,
              'hasWorkout': false,
              'isOffDay': false,
              'completed': false,
              'status': 'none',
            })
        : days;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrevWeek, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            Expanded(
              child: Column(
                children: [
                  const Text('Weekly Plan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(weekLabel, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNextWeek, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ],
        ),
        if (!isCurrentWeek)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onJumpToCurrentWeek,
                icon: const Icon(Icons.today_rounded, size: 16),
                label: const Text('This week'),
                style: TextButton.styleFrom(
                  foregroundColor: CoachDashboardTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
        Text(
          days.isEmpty
              ? 'No workouts scheduled this week'
              : '${summary['completed'] ?? 0}/${summary['workoutDays'] ?? 0} completed'
                  '${(summary['offDays'] as int? ?? 0) > 0 ? ' · ${summary['offDays']} off' : ''}',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
        ),
        const SizedBox(height: 12),
        ...List.generate(dayRows.length.clamp(0, 7), (i) {
          final day = dayRows[i] as Map<String, dynamic>;
          final has = day['hasWorkout'] == true;
          final isOff = day['isOffDay'] == true || day['status'] == 'off';
          final status = day['status'] as String? ?? 'none';
          final schedule = day['schedule'] as Map<String, dynamic>?;
          final title = schedule?['title'] as String? ?? schedule?['workoutTemplate']?['title'] as String? ?? '';
          final dayExercises = schedule?['exercises'] as List<dynamic>?
              ?? schedule?['workoutTemplate']?['exercises'] as List<dynamic>?
              ?? const [];
          final exercisePreview = dayExercises
              .map((e) => e is Map ? e['name']?.toString() : null)
              .whereType<String>()
              .take(2)
              .join(', ');
          final timeStr = _formatTime(schedule?['startDateTime']?.toString());
          final dayDate = weekDayDate(weekStart, i);
          final dayLabel = '${labels[i]} ${dayDate.month}/${dayDate.day}';
          final completed = day['completed'] == true || status == 'completed';
          final inReview = status == 'pending_review';
          final missed = status == 'missed';
          final canMarkDay = has && !completed && !inReview;

          Color statusColor = Colors.grey;
          String statusLabel = 'Rest';
          String mainLabel = 'No workout';
          if (isOff) {
            statusColor = Colors.blueGrey;
            statusLabel = 'Off day';
            mainLabel = 'Holiday / off day';
          } else if (has) {
            mainLabel = title;
            if (completed) {
              statusColor = CoachDashboardTheme.success;
              statusLabel = 'Approved';
            } else if (inReview) {
              statusColor = CoachDashboardTheme.warning;
              statusLabel = 'Pending Review';
            } else if (status == 'missed') {
              statusColor = CoachDashboardTheme.danger;
              statusLabel = 'Missed';
            } else {
              statusColor = Colors.orange;
              statusLabel = 'Assigned';
            }
          }

          return GestureDetector(
            onTap: has ? () => onDayTap(day) : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: has
                    ? (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50)
                    : isOff
                        ? Colors.blueGrey.withValues(alpha: isDark ? 0.08 : 0.06)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isOff
                      ? Colors.blueGrey.withValues(alpha: 0.35)
                      : (isDark ? Colors.white10 : Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  if (has && onCompleteWorkout != null) ...[
                    WorkoutMarkCompleteControl(
                      status: completed
                          ? 'completed'
                          : (inReview ? 'pending_review' : (missed ? 'missed' : 'pending')),
                      isLoading: completing && canMarkDay,
                      onMarkComplete: canMarkDay && !completing
                          ? () {
                              final id = schedule?['_id']?.toString();
                              if (id != null && id.isNotEmpty) onCompleteWorkout!(id);
                            }
                          : null,
                    ),
                    const SizedBox(width: 4),
                  ],
                  SizedBox(
                    width: 52,
                    child: Text(dayLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black87)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mainLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: has || isOff ? FontWeight.w600 : FontWeight.normal,
                            color: has ? null : (isOff ? Colors.blueGrey : Colors.grey),
                          ),
                        ),
                        if (has && timeStr.isNotEmpty)
                          Text(timeStr, style: const TextStyle(fontSize: 11, color: CoachDashboardTheme.primary)),
                        if (has && exercisePreview.isNotEmpty)
                          Text(
                            exercisePreview + (dayExercises.length > 2 ? '…' : ''),
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                ],
              ),
            ),
          );
        }),
      ]),
    );
  }
}
