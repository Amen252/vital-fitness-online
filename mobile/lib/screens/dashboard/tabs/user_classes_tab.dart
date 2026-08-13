import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../user_class_detail_screen.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/api_service.dart';
import '../../../widgets/scrollable_body.dart';
import '../../../widgets/tab_refresh.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../utils/async_load.dart';
import '../../../utils/date_utils.dart';
import '../../../utils/workout_media_urls.dart';
import '../../../widgets/workout_proof_sheet.dart';
import '../../../widgets/workout_mark_complete_control.dart';
import '../../../widgets/silent_refresh.dart';

class UserClassesTab extends StatefulWidget {
  final User user;
  final bool embedded;
  final VoidCallback? onViewWorkoutSchedule;
  final VoidCallback? onScheduleDataChanged;
  final Future<void> Function()? onParentRefresh;

  const UserClassesTab({
    super.key,
    required this.user,
    this.embedded = false,
    this.onViewWorkoutSchedule,
    this.onScheduleDataChanged,
    this.onParentRefresh,
  });

  @override
  State<UserClassesTab> createState() => UserClassesTabState();
}

class UserClassesTabState extends State<UserClassesTab>
    with SingleTickerProviderStateMixin, TabRefreshMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _classes = [];
  List<dynamic> _availableClasses = [];
  List<dynamic> _sessions = [];
  List<dynamic> _workoutSchedules = [];
  bool _completingSchedule = false;
  String? _completingId;
  String? _joiningClassId;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> refresh({bool isRefresh = true}) => _fetchData(isRefresh: isRefresh);

  Future<void> _refreshAll() async {
    await Future.wait([
      _fetchData(isRefresh: true),
      if (widget.onParentRefresh != null) widget.onParentRefresh!() else Future.value(),
    ]);
  }

  Future<void> _fetchData({bool isRefresh = false}) async {
    beginTabLoad(isRefresh: isRefresh);
    try {
      final results = await waitIsolatedTimed<Object?>([
        _apiService.getUserClasses(),
        _apiService.getAvailableClasses(),
        _apiService.getUserSessions(),
        _apiService.getUserWorkoutSchedules(),
      ], fallback: null);
      if (results.every((r) => r == null)) {
        finishTabError(
          Exception('Unable to load workouts. Please retry.'),
          isRefresh: isRefresh,
        );
        return;
      }
      if (mounted) {
        finishTabLoad(() {
          _classes = results[0] is List ? List<dynamic>.from(results[0] as List) : <dynamic>[];
          _availableClasses = results[1] is List ? List<dynamic>.from(results[1] as List) : <dynamic>[];
          final sessionsRaw = results[2] is List ? results[2] as List : const [];
          _sessions = sessionsRaw.map((raw) {
            final map = Map<String, dynamic>.from(raw as Map);
            map['_isOneOnOne'] = true;
            return map;
          }).toList();
          final scheduleData = results[3] is Map
              ? Map<String, dynamic>.from(results[3] as Map)
              : <String, dynamic>{};
          _workoutSchedules = List<dynamic>.from(scheduleData['all'] as List<dynamic>? ?? []);
        });
      }
    } catch (e) {
      finishTabError(e, isRefresh: isRefresh);
    } finally {
      if (mounted && (tabIsLoading || tabIsRefreshing)) {
        setState(() {
          tabIsLoading = false;
          tabIsRefreshing = false;
        });
      }
    }
  }

  void _openClassDetail(String classId, {Map<String, dynamic>? initialData}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserClassDetailScreen(
          classId: classId,
          initialData: initialData,
          onUpdated: () => _fetchData(isRefresh: true),
          onViewWorkoutSchedule: widget.onViewWorkoutSchedule,
        ),
      ),
    );
  }

  Future<void> _completeWorkoutSchedule(String scheduleId, {String title = 'Workout'}) async {
    final proof = await showWorkoutProofSheet(context, workoutTitle: title);
    if (proof == null || !mounted) return;

    setState(() {
      _completingSchedule = true;
      _completingId = scheduleId;
    });
    try {
      await _apiService.completeWorkoutSchedule(
        scheduleId,
        notes: proof['notes'] as String,
        durationMinutes: proof['durationMinutes'] as int,
        proofPhoto: proof['proofPhoto'] as String,
      );
      if (mounted) {
        setState(() {
          _completingSchedule = false;
          _completingId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Submitted for coach review · Streak updates when your coach approves'),
            backgroundColor: CoachDashboardTheme.warning,
          ),
        );
      }
      // Background refresh only — do not block Complete on reloads.
      _fetchData(isRefresh: true);
      widget.onScheduleDataChanged?.call();
      widget.onParentRefresh?.call();
    } catch (e) {
      if (mounted) {
        setState(() {
          _completingSchedule = false;
          _completingId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: CoachDashboardTheme.danger),
        );
      }
    } finally {
      if (mounted && _completingSchedule) {
        setState(() {
          _completingSchedule = false;
          _completingId = null;
        });
      }
    }
  }

  void _showWorkoutDetail(Map<String, dynamic> item) {
    final workout = item['workoutTemplate'] as Map<String, dynamic>? ??
        item['workout'] as Map<String, dynamic>? ??
        {};
    // Prefer the schedule's own exercise snapshot (includes coach demoVideoUrl),
    // then fall back to the linked workout template.
    final exercises = (item['exercises'] as List<dynamic>?) ??
        (workout['exercises'] as List<dynamic>?) ??
        const [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF181B24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['title']?.toString() ?? workout['title']?.toString() ?? 'Workout', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(formatApiDateTime(item['startDateTime']?.toString()), style: const TextStyle(color: CoachDashboardTheme.primary)),
            if (item['coach']?['name'] != null)
              Text('Coach: ${item['coach']['name']}', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade700)),
            if ((item['notes'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Coach notes', style: CoachDashboardTheme.sectionTitle(isDark)),
              Text(item['notes'].toString()),
            ],
            if (exercises.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Exercises', style: CoachDashboardTheme.sectionTitle(isDark)),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: exercises.map((ex) {
                      final map = ex is Map
                          ? Map<dynamic, dynamic>.from(ex)
                          : <dynamic, dynamic>{'name': ex?.toString() ?? 'Exercise'};
                      return WorkoutExerciseRow(exercise: map, isDark: isDark);
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _joinClass(String classId, {bool openDetail = false}) async {
    setState(() => _joiningClassId = classId);
    try {
      final result = await _apiService.joinUserClass(classId);
      await _fetchData(isRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Joined class successfully!'),
            backgroundColor: CoachDashboardTheme.success,
          ),
        );
        if (openDetail) {
          _openClassDetail(classId, initialData: Map<String, dynamic>.from(result));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _joiningClassId = null);
    }
  }

  List<dynamic> get _upcomingAvailable {
    final now = DateTime.now();
    return _availableClasses.where((item) {
      final dateStr = item['date'] as String? ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.isAfter(now);
    }).toList();
  }

  List<dynamic> get _upcoming {
    final now = DateTime.now();
    final list = [..._classes, ..._sessions, ..._workoutSchedules];
    return list.where((item) {
      final dateStr = item['date'] as String? ??
          item['dateTime'] as String? ??
          item['datetime'] as String? ??
          item['scheduledAt'] as String? ??
          item['startDateTime'] as String? ??
          '';
      final d = DateTime.tryParse(dateStr);
      final status = item['status'] as String? ?? item['completion']?['status'] as String? ?? '';
      if (['completed', 'cancelled', 'rejected', 'no_show'].contains(status)) return false;
      if (status == 'in_progress') return true;
      return d != null && d.isAfter(now.subtract(const Duration(hours: 1)));
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse((a['date'] ?? a['dateTime'] ?? a['datetime'] ?? a['scheduledAt'] ?? a['startDateTime'] ?? '') as String) ?? DateTime(2100);
        final db = DateTime.tryParse((b['date'] ?? b['dateTime'] ?? b['datetime'] ?? b['scheduledAt'] ?? b['startDateTime'] ?? '') as String) ?? DateTime(2100);
        return da.compareTo(db);
      });
  }

  List<dynamic> get _history {
    final now = DateTime.now();
    final list = [..._classes, ..._sessions, ..._workoutSchedules];
    return list.where((item) {
      final dateStr = item['date'] as String? ??
          item['dateTime'] as String? ??
          item['datetime'] as String? ??
          item['scheduledAt'] as String? ??
          item['startDateTime'] as String? ??
          '';
      final d = DateTime.tryParse(dateStr);
      final completionStatus = item['completion']?['status'] as String?;
      final status = item['status'] as String? ?? '';
      if (completionStatus == 'completed') return true;
      if (['completed', 'cancelled', 'rejected', 'no_show'].contains(status)) return true;
      return d != null && d.isBefore(now.subtract(const Duration(hours: 1))) && status != 'in_progress';
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse((a['date'] ?? a['dateTime'] ?? a['datetime'] ?? a['scheduledAt'] ?? a['startDateTime'] ?? '') as String) ?? DateTime(0);
        final db = DateTime.tryParse((b['date'] ?? b['dateTime'] ?? b['datetime'] ?? b['scheduledAt'] ?? b['startDateTime'] ?? '') as String) ?? DateTime(0);
        return db.compareTo(da);
      });
  }

  String _formatDateTime(String? raw) {
    if (raw == null) return 'N/A';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour < 12 ? 'AM' : 'PM';
    return '${days[dt.weekday - 1]}, ${months[dt.month]} ${dt.day} · $h:$m $suffix';
  }

  Widget _buildContent(bool isDark) {
    if (showInitialError) {
      return ScrollableCenter(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFFF6B6B), size: 48),
          const SizedBox(height: 12),
          Text(tabLoadError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => _fetchData(), child: const Text('Retry')),
        ]),
      );
    }
    return SilentRefreshIndicator(
      onRefresh: widget.embedded ? _refreshAll : () => _fetchData(isRefresh: true),
      color: CoachDashboardTheme.primary,
      child: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildClassList(_upcoming, isDark, isUpcoming: true),
          _buildClassList(_history, isDark, isUpcoming: false),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.embedded) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_upcoming.length} upcoming · ${_history.length} completed',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh classes',
                  onPressed: (showInitialLoading || tabIsRefreshing) ? null : _refreshAll,
                  icon: tabRefreshIcon(color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary, size: 22),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabCtrl,
            labelColor: CoachDashboardTheme.primary,
            unselectedLabelColor: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
            indicatorColor: CoachDashboardTheme.primary,
            tabs: const [Tab(text: 'Upcoming'), Tab(text: 'History')],
          ),
          Expanded(child: _buildContent(isDark)),
        ],
      );
    }

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: CoachDashboardTheme.headerGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                      child: Text('My Classes', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: (showInitialLoading || tabIsRefreshing) ? null : () => refresh(),
                      icon: tabRefreshIcon(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${_upcoming.length} upcoming · ${_history.length} completed',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: CoachDashboardTheme.primary,
                    unselectedLabelColor: Colors.white,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: '  Upcoming  '),
                      Tab(text: '  History  '),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
        body: _buildContent(isDark),
      ),
    );
  }

  Widget _buildClassList(List<dynamic> items, bool isDark, {required bool isUpcoming}) {
    final available = isUpcoming ? _upcomingAvailable : <dynamic>[];
    final isEmpty = items.isEmpty && available.isEmpty;

    if (isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isUpcoming ? Icons.event_available_rounded : Icons.history_rounded,
                          size: 64,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isUpcoming ? 'No upcoming classes' : 'No class history yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isUpcoming
                              ? 'When your coach adds you to a group, it will appear here.'
                              : 'Completed classes will appear here.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (available.isNotEmpty) ...[
          Text('Available to Join', style: CoachDashboardTheme.sectionTitle(isDark)),
          const SizedBox(height: 4),
          Text(
            'Join a group class from your coach.',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          ...available.map((c) => _buildClassCard(c, isDark, isUpcoming: true, isAvailable: true)),
          const SizedBox(height: 20),
          Text('My Classes', style: CoachDashboardTheme.sectionTitle(isDark)),
          const SizedBox(height: 12),
        ],
        ...items.map((c) => _buildClassCard(c, isDark, isUpcoming: isUpcoming)),
      ],
    );
  }

  Widget _buildClassCard(Map<dynamic, dynamic> item, bool isDark, {required bool isUpcoming, bool isAvailable = false}) {
    final isOneOnOne = item['_isOneOnOne'] == true ||
        (item['sessionMode'] != null && item['title'] == null && item['category'] == null && item['type'] != 'workout_schedule');
    if (isOneOnOne) {
      return _buildOneOnOneCard(Map<String, dynamic>.from(item), isDark, isUpcoming: isUpcoming);
    }

    final classId = item['_id']?.toString() ?? '';
    final title = item['title'] as String? ?? item['type'] as String? ?? 'Training Session';
    final isWorkoutSchedule = item['type'] == 'workout_schedule';
    final dateStr = item['date'] as String? ?? item['scheduledAt'] as String? ?? item['startDateTime'] as String? ?? '';
    final coachName = item['coach']?['name'] as String? ??
        item['coach']?['full_name'] as String? ??
        item['coach']?['username'] as String? ??
        item['trainer']?['name'] as String? ??
        'Your Coach';
    final duration = item['durationMinutes'] as int? ?? item['duration'] as int? ?? 60;
    final completionStatus = item['completion']?['status'] as String? ?? '';
    final status = completionStatus.isNotEmpty
        ? completionStatus
        : (item['status'] as String? ?? (isUpcoming ? 'scheduled' : 'completed'));
    final isPendingTask = isWorkoutSchedule && (status == 'pending' || status == 'missed');
    final isCompletedTask = isWorkoutSchedule && status == 'completed';
    final isInReviewTask = isWorkoutSchedule && status == 'pending_review';
    final scheduleId = item['_id']?.toString() ?? '';
    final notes = item['description'] as String? ?? item['notes'] as String? ?? '';
    final category = item['category'] as String? ?? '';
    final enrolledCount = item['enrolledCount'] as int? ?? (item['enrolledStudents'] as List?)?.length ?? 0;
    final capacity = item['capacity'] as int? ?? 0;
    final hasJoined = item['hasJoined'] == true;
    final sessionOpen = item['sessionOpen'] == true;
    final isJoining = _joiningClassId == classId;

    final statusColor = _statusColor(status);
    final cardColors = isUpcoming
        ? [CoachDashboardTheme.primary.withOpacity(0.08), CoachDashboardTheme.primaryLight.withOpacity(0.04)]
        : [Colors.grey.withOpacity(0.06), Colors.grey.withOpacity(0.03)];

    final isFitnessClass = !isWorkoutSchedule && classId.isNotEmpty && item['title'] != null && item['category'] != null;

    return GestureDetector(
      onTap: isFitnessClass
          ? () => _openClassDetail(classId, initialData: Map<String, dynamic>.from(item))
          : isWorkoutSchedule
              ? () => _showWorkoutDetail(Map<String, dynamic>.from(item))
              : null,
      child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: cardColors),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUpcoming ? CoachDashboardTheme.primary.withOpacity(0.2) : Colors.grey.withOpacity(0.15),
        ),
        color: isDark ? const Color(0xFF181B24) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (isWorkoutSchedule && (isPendingTask || isCompletedTask || isInReviewTask))
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: WorkoutMarkCompleteControl(
                  status: isCompletedTask
                      ? 'completed'
                      : (isInReviewTask ? 'pending_review' : 'pending'),
                  isLoading: _completingSchedule && _completingId == scheduleId,
                  onMarkComplete: isPendingTask && !_completingSchedule
                      ? () => _completeWorkoutSchedule(
                            scheduleId,
                            title: item['title']?.toString() ??
                                item['workoutTemplate']?['title']?.toString() ??
                                'Workout',
                          )
                      : null,
                ),
              ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isUpcoming ? CoachDashboardTheme.primary : Colors.grey).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isWorkoutSchedule
                    ? Icons.event_note_rounded
                    : (isUpcoming ? Icons.fitness_center_rounded : Icons.check_circle_outline_rounded),
                color: isUpcoming ? CoachDashboardTheme.primary : Colors.grey,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 3),
              Text(
                isWorkoutSchedule
                    ? 'Scheduled workout · $coachName'
                    : 'with $coachName',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isWorkoutSchedule && status == 'completed'
                    ? 'Completed'
                    : isWorkoutSchedule && status == 'pending'
                        ? 'Pending'
                        : status.toUpperCase(),
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Expanded(child: Text(_formatDateTime(dateStr), style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
            Icon(Icons.timer_outlined, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Text('$duration min', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ]),
          if (category.isNotEmpty || capacity > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (category.isNotEmpty) ...[
                  Icon(Icons.category_outlined, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(category, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 12),
                ],
                if (capacity > 0) ...[
                  Icon(Icons.groups_outlined, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text('$enrolledCount/$capacity members', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ],
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(notes, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic)),
          ],
          if (isFitnessClass) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openClassDetail(classId, initialData: Map<String, dynamic>.from(item)),
                    icon: const Icon(Icons.visibility_rounded, size: 18),
                    label: const Text('View Schedule'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CoachDashboardTheme.primary,
                      side: const BorderSide(color: CoachDashboardTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                if (isUpcoming) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Builder(builder: (context) {
                      final canJoin = !isJoining && (isAvailable || (!hasJoined && sessionOpen));
                      final label = isAvailable
                          ? 'Join'
                          : hasJoined
                              ? 'Joined'
                              : sessionOpen
                                  ? 'Join Live'
                                  : 'Soon';
                      final icon = isJoining
                          ? null
                          : isAvailable
                              ? Icons.group_add_rounded
                              : hasJoined
                                  ? Icons.check_circle_rounded
                                  : sessionOpen
                                      ? Icons.play_circle_rounded
                                      : Icons.schedule_rounded;

                      return ElevatedButton.icon(
                        onPressed: canJoin ? () => _joinClass(classId, openDetail: true) : null,
                        icon: isJoining
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: const SizedBox.shrink(),
                              )
                            : Icon(icon, size: 18),
                        label: Text(label),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasJoined && !isAvailable
                              ? CoachDashboardTheme.success
                              : CoachDashboardTheme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: (hasJoined && !isAvailable
                                  ? CoachDashboardTheme.success
                                  : CoachDashboardTheme.primary)
                              .withOpacity(0.5),
                          disabledForegroundColor: Colors.white70,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ],
          if (isWorkoutSchedule) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showWorkoutDetail(Map<String, dynamic>.from(item)),
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: const Text('View Workout Details'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CoachDashboardTheme.primary,
                  side: const BorderSide(color: CoachDashboardTheme.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ],
        ]),
      ),
    ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Colors.green;
      case 'confirmed':
      case 'approved': return const Color(0xFF00D4AA);
      case 'in_progress': return const Color(0xFF0EA5E9);
      case 'cancelled':
      case 'rejected':
      case 'no_show': return const Color(0xFFFF6B6B);
      case 'pending':
      case 'rescheduled': return const Color(0xFFFFB74D);
      default: return CoachDashboardTheme.primary;
    }
  }

  String _oneOnOneStatusLabel(String status) {
    switch (status) {
      case 'approved':
      case 'confirmed':
        return 'Confirmed';
      case 'in_progress':
        return 'In Progress';
      case 'pending':
        return 'Pending';
      case 'completed':
        return 'Completed';
      case 'cancelled':
      case 'rejected':
        return 'Cancelled';
      case 'rescheduled':
        return 'Rescheduled';
      case 'no_show':
        return 'Missed';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  Widget _buildOneOnOneCard(Map<String, dynamic> item, bool isDark, {required bool isUpcoming}) {
    final status = item['status']?.toString() ?? (isUpcoming ? 'pending' : 'completed');
    final statusColor = _statusColor(status);
    final coachMap = item['coach'] is Map ? Map<dynamic, dynamic>.from(item['coach'] as Map) : null;
    final coachName = ApiService.displayName(coachMap, fallback: 'Your Coach');
    final photo = coachMap?['avatar']?.toString() ?? coachMap?['photoUrl']?.toString();
    final dateStr = (item['dateTime'] ?? item['datetime'] ?? item['date'] ?? '').toString();
    final duration = item['durationMinutes'] ?? item['duration'] ?? 60;
    final mode = item['sessionMode']?.toString() == 'online' ? 'Online' : 'In Person';
    final notes = item['notes']?.toString().trim() ?? '';
    final coachNotes = item['coachNotes']?.toString().trim() ?? '';
    final meetingLink = item['meetingLink']?.toString().trim() ?? '';
    final canJoin = meetingLink.isNotEmpty &&
        ['approved', 'confirmed', 'rescheduled', 'in_progress'].contains(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181B24) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUpcoming ? CoachDashboardTheme.primary.withOpacity(0.2) : Colors.grey.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(name: coachName, photoUrl: photo, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1-on-1 Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('with $coachName', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _oneOnOneStatusLabel(status),
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Expanded(child: Text(_formatDateTime(dateStr), style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
              Icon(Icons.timer_outlined, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text('$duration min · $mode', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(notes, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic)),
          ],
          if (status == 'completed' && coachNotes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Coach notes: $coachNotes', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
          if (canJoin) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(meetingLink);
                  if (uri == null) return;
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.videocam_rounded),
                label: const Text('Join online session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CoachDashboardTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
