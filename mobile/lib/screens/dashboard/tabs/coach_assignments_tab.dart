import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../utils/async_load.dart';
import '../../../widgets/coach_workout_detail_sheet.dart';
import '../../../widgets/scrollable_body.dart';
import '../../../widgets/tab_refresh.dart';
import '../../../utils/date_utils.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';
import 'workout_form_sheet.dart';
import 'workout_schedule_form_sheet.dart';
import 'weekly_workout_plan_form_sheet.dart';

class CoachAssignmentsTab extends StatefulWidget {
  const CoachAssignmentsTab({super.key});

  @override
  State<CoachAssignmentsTab> createState() => _CoachAssignmentsTabState();
}

class _CoachAssignmentsTabState extends State<CoachAssignmentsTab> with TickerProviderStateMixin, TabRefreshMixin {
  final ApiService _apiService = ApiService();
  late final TabController _mainTab;
  late final TabController _scheduleFilterTab;

  List<dynamic> _templates = [];
  List<dynamic> _clients = [];
  List<dynamic> _classes = [];
  List<dynamic> _schedules = [];
  List<dynamic> _weeklyPlans = [];
  Map<String, dynamic> _scheduleSummary = {};

  @override
  void initState() {
    super.initState();
    _mainTab = TabController(length: 2, vsync: this);
    _scheduleFilterTab = TabController(length: 3, vsync: this);
    _mainTab.addListener(() {
      if (!_mainTab.indexIsChanging) setState(() {});
    });
    _fetchData();
  }

  @override
  void dispose() {
    _mainTab.dispose();
    _scheduleFilterTab.dispose();
    super.dispose();
  }

  Future<void> _fetchData({bool isRefresh = false}) async {
    beginTabLoad(isRefresh: isRefresh);
    try {
      // Isolate each call so one slow endpoint cannot freeze Workout Management.
      // Clients use light=1 (no snapshots) — this screen only needs ids/names.
      final results = await waitIsolatedTimed<Object?>([
        _apiService.getWorkoutTemplates(),
        _apiService.getCoachClients(light: true),
        _apiService.getCoachClasses(),
        _apiService.getCoachWorkoutSchedules(),
        _apiService.getCoachWeeklyWorkoutPlans(),
      ], fallback: null);

      final templates = results[0] is List ? List<dynamic>.from(results[0] as List) : <dynamic>[];
      final clients = results[1] is List ? List<dynamic>.from(results[1] as List) : <dynamic>[];
      final classes = results[2] is List ? List<dynamic>.from(results[2] as List) : <dynamic>[];
      final scheduleData = results[3] is Map
          ? Map<String, dynamic>.from(results[3] as Map)
          : <String, dynamic>{};
      final weeklyPlans = results[4] is List ? List<dynamic>.from(results[4] as List) : <dynamic>[];

      final allFailed = results.every((r) => r == null);
      if (allFailed) {
        finishTabError(
          Exception('Unable to load workout data. Please retry.'),
          isRefresh: isRefresh,
        );
        return;
      }

      if (mounted) {
        finishTabLoad(() {
          _templates = templates;
          _clients = clients;
          _classes = classes;
          _schedules = List<dynamic>.from(scheduleData['schedules'] as List<dynamic>? ?? []);
          _weeklyPlans = weeklyPlans;
          _scheduleSummary = Map<String, dynamic>.from(
            scheduleData['summary'] as Map<String, dynamic>? ?? {},
          );
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

  void _openTemplateForm({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WorkoutFormSheet(
        targetLabel: 'Workout Template',
        existingPlan: existing,
        apiService: _apiService,
        onSaved: () => _fetchData(isRefresh: true),
      ),
    );
  }

  void _openScheduleForm({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WorkoutScheduleFormSheet(
        templates: _templates,
        clients: _clients,
        classes: _classes,
        apiService: _apiService,
        existingSchedule: existing,
        onSaved: () => _fetchData(isRefresh: true),
      ),
    );
  }

  void _openWeeklyPlanForm({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WeeklyWorkoutPlanFormSheet(
        templates: _templates,
        clients: _clients,
        classes: _classes,
        apiService: _apiService,
        existingPlan: existing,
        onSaved: () => _fetchData(isRefresh: true),
        onDelete: _deleteWeeklyPlan,
      ),
    ).then((saved) {
      if (saved == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weekly plan saved — schedules created!'), backgroundColor: CoachDashboardTheme.success),
        );
      }
    });
  }

  Future<void> _deleteWeeklyPlan(String id) async {
    await _apiService.deleteWeeklyWorkoutPlan(id);
  }

  void _showScheduleAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_rounded),
              title: const Text('Add Single Schedule'),
              onTap: () {
                Navigator.pop(ctx);
                _openScheduleForm();
              },
            ),
            ListTile(
              leading: const Icon(Icons.view_week_rounded),
              title: const Text('Create Weekly Plan'),
              subtitle: const Text('Mon–Sun daily workouts'),
              onTap: () {
                Navigator.pop(ctx);
                _openWeeklyPlanForm();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (showInitialLoading) {
      return const CoachPage(
        title: 'Workout Management',
        body: ScrollableCenter(child: CircularProgressIndicator(color: CoachDashboardTheme.primary)),
      );
    }

    if (showInitialError) {
      return CoachPage(
        title: 'Workout Management',
        body: ScrollableCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tabLoadError!, textAlign: TextAlign.center, style: const TextStyle(color: CoachDashboardTheme.danger)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => _fetchData(), child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return CoachPage(
      title: 'Workout Management',
      centerTitle: false,
      actions: [
        IconButton(
          icon: tabRefreshIcon(color: Colors.white),
          onPressed: (tabIsRefreshing) ? null : () => _fetchData(isRefresh: true),
        ),
      ],
      bottom: TabBar(
        controller: _mainTab,
        labelColor: CoachDashboardTheme.primary,
        unselectedLabelColor: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
        indicatorColor: CoachDashboardTheme.primary,
        tabs: const [
          Tab(text: 'Workouts'),
          Tab(text: 'Schedule'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mainTab.index == 0 ? () => _openTemplateForm() : _showScheduleAddMenu,
        icon: const Icon(Icons.add_rounded),
        label: Text(_mainTab.index == 0 ? 'Create Workout' : 'Add'),
        backgroundColor: CoachDashboardTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: TabBarView(
        controller: _mainTab,
        children: [
          _WorkoutTemplatesView(
            isDark: isDark,
            templates: _templates,
            onEdit: (t) => _openTemplateForm(existing: t),
            onDelete: _deleteTemplate,
            onRefresh: () => _fetchData(isRefresh: true),
          ),
          _ScheduleManagementView(
            isDark: isDark,
            schedules: _schedules,
            weeklyPlans: _weeklyPlans,
            summary: _scheduleSummary,
            clients: _clients,
            classes: _classes,
            filterTab: _scheduleFilterTab,
            apiService: _apiService,
            onEdit: (s) => _openScheduleForm(existing: s),
            onEditWeekly: (p) => _openWeeklyPlanForm(existing: p),
            onDeleteWeekly: _confirmDeleteWeeklyPlan,
            onRefresh: () => _fetchData(isRefresh: true),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteWeeklyPlan(Map<String, dynamic> plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete weekly plan?'),
        content: const Text('All linked schedule entries for this plan will be cancelled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: CoachDashboardTheme.danger))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _deleteWeeklyPlan(plan['_id'].toString());
      _fetchData(isRefresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: CoachDashboardTheme.danger),
        );
      }
    }
  }

  Future<void> _deleteTemplate(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete workout?'),
        content: const Text('This removes the template. Existing schedules keep their reference.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: CoachDashboardTheme.danger))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _apiService.deleteWorkoutTemplate(id);
      _fetchData(isRefresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: CoachDashboardTheme.danger),
        );
      }
    }
  }
}

class _WorkoutTemplatesView extends StatefulWidget {
  final bool isDark;
  final List<dynamic> templates;
  final void Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(String id) onDelete;
  final VoidCallback onRefresh;

  const _WorkoutTemplatesView({
    required this.isDark,
    required this.templates,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  State<_WorkoutTemplatesView> createState() => _WorkoutTemplatesViewState();
}

class _WorkoutTemplatesViewState extends State<_WorkoutTemplatesView> {
  String _query = '';

  List<dynamic> get _filtered {
    if (_query.isEmpty) return widget.templates;
    final q = _query.toLowerCase();
    return widget.templates.where((t) {
      final title = (t['title'] as String? ?? '').toLowerCase();
      final level = (t['level'] as String? ?? '').toLowerCase();
      return title.contains(q) || level.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SearchField(isDark: widget.isDark, hint: 'Search workouts', onChanged: (v) => setState(() => _query = v)),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => widget.onRefresh(),
            color: CoachDashboardTheme.primary,
            child: _filtered.isEmpty
                ? refreshableScrollChild(
                    context: context,
                    child: CoachDashboardTheme.emptyState(icon: Icons.fitness_center_outlined, message: 'No workout templates yet', isDark: widget.isDark),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                    final t = Map<String, dynamic>.from(_filtered[index] as Map);
                    final exercises = t['exercises'] as List<dynamic>? ?? [];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: CoachDashboardTheme.cardDecoration(widget.isDark),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(t['title']?.toString() ?? 'Workout', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                              Text(t['level']?.toString() ?? '', style: const TextStyle(color: CoachDashboardTheme.primary, fontSize: 12)),
                            ],
                          ),
                          if ((t['description'] as String? ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(t['description'].toString(), style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white54 : Colors.grey)),
                          ],
                          const SizedBox(height: 8),
                          ...exercises.take(5).map((ex) => Text(
                                '• ${ex['name']} — ${ex['sets']}×${ex['reps']}${ex['durationMinutes'] != null ? ' · ${ex['durationMinutes']}min' : ''}${ex['restSeconds'] != null ? ' · ${ex['restSeconds']}s rest' : ''}',
                                style: const TextStyle(fontSize: 12, height: 1.4),
                              )),
                          if (exercises.length > 5)
                            Text('+ ${exercises.length - 5} more', style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white38 : Colors.grey)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            children: [
                              TextButton.icon(
                                onPressed: () => showCoachWorkoutDetailSheet(
                                  context,
                                  kind: CoachWorkoutDetailKind.template,
                                  data: t,
                                ),
                                icon: const Icon(Icons.visibility_outlined, size: 16),
                                label: const Text('View'),
                              ),
                              TextButton.icon(onPressed: () => widget.onEdit(t), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit')),
                              TextButton.icon(
                                onPressed: () => widget.onDelete(t['_id'].toString()),
                                icon: const Icon(Icons.delete_outline, size: 16, color: CoachDashboardTheme.danger),
                                label: const Text('Delete', style: TextStyle(color: CoachDashboardTheme.danger)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ),
      ],
    );
  }
}

class _ScheduleManagementView extends StatefulWidget {
  final bool isDark;
  final List<dynamic> schedules;
  final List<dynamic> weeklyPlans;
  final Map<String, dynamic> summary;
  final List<dynamic> clients;
  final List<dynamic> classes;
  final TabController filterTab;
  final ApiService apiService;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onEditWeekly;
  final Future<void> Function(Map<String, dynamic>) onDeleteWeekly;
  final VoidCallback onRefresh;

  const _ScheduleManagementView({
    required this.isDark,
    required this.schedules,
    required this.weeklyPlans,
    required this.summary,
    required this.clients,
    required this.classes,
    required this.filterTab,
    required this.apiService,
    required this.onEdit,
    required this.onEditWeekly,
    required this.onDeleteWeekly,
    required this.onRefresh,
  });

  @override
  State<_ScheduleManagementView> createState() => _ScheduleManagementViewState();
}

class _ScheduleManagementViewState extends State<_ScheduleManagementView> {
  String _query = '';

  List<dynamic> get _displayWeeklyPlans {
    List<dynamic> list = widget.weeklyPlans;
    final filter = widget.filterTab.index;
    if (filter == 1) {
      list = list.where((p) => p['client'] != null).toList();
    } else if (filter == 2) {
      list = list.where((p) => p['fitnessClass'] != null).toList();
    }
    if (_query.isEmpty) return list;
    final q = _query.toLowerCase();
    return list.where((p) {
      final title = (p['title'] as String? ?? '').toLowerCase();
      final client = ApiService.displayName(
        p['client'] is Map ? Map<dynamic, dynamic>.from(p['client'] as Map) : null,
        fallback: '',
      ).toLowerCase();
      final group = (p['fitnessClass']?['title'] as String? ?? '').toLowerCase();
      return title.contains(q) || client.contains(q) || group.contains(q);
    }).toList();
  }

  List<dynamic> get _displaySchedules {
    // Standalone schedules only — weekly-plan workouts are managed in Weekly Plans above.
    List<dynamic> list = widget.schedules.where((s) => s['weeklyPlan'] == null).toList();
    final filter = widget.filterTab.index;
    if (filter == 1) {
      list = list.where((s) => s['client'] != null).toList();
    } else if (filter == 2) {
      list = list.where((s) => s['fitnessClass'] != null).toList();
    }
    if (_query.isEmpty) return list;
    final q = _query.toLowerCase();
    return list.where((s) {
      final title = (s['title'] as String? ?? s['workoutTemplate']?['title'] as String? ?? '').toLowerCase();
      final client = ApiService.displayName(
        s['client'] is Map ? Map<dynamic, dynamic>.from(s['client'] as Map) : null,
        fallback: '',
      ).toLowerCase();
      final group = (s['fitnessClass']?['title'] as String? ?? '').toLowerCase();
      return title.contains(q) || client.contains(q) || group.contains(q);
    }).toList();
  }

  Future<void> _deleteSchedule(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete schedule?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: CoachDashboardTheme.danger))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.apiService.deleteWorkoutSchedule(id);
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: CoachDashboardTheme.danger));
      }
    }
  }

  String _formatRange(Map<String, dynamic> s) =>
      formatScheduleRange(s['startDateTime']?.toString(), s['endDateTime']?.toString());

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _ProgressSummaryCard(
            isDark: widget.isDark,
            completed: summary['completed'] as int? ?? 0,
            pending: summary['pending'] as int? ?? 0,
            missed: summary['missed'] as int? ?? 0,
            percent: summary['completionPercent'] as int? ?? 0,
          ),
        ),
        TabBar(
          controller: widget.filterTab,
          labelColor: CoachDashboardTheme.primary,
          unselectedLabelColor: widget.isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
          indicatorColor: CoachDashboardTheme.primary,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'By User'),
            Tab(text: 'By Group'),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => widget.onRefresh(),
            color: CoachDashboardTheme.primary,
            child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              if (_displayWeeklyPlans.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Weekly Plans', style: CoachDashboardTheme.sectionTitle(widget.isDark)),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final p = Map<String, dynamic>.from(_displayWeeklyPlans[index] as Map);
                      final assignee = p['fitnessClass'] != null
                          ? (p['fitnessClass']?['title'] as String? ?? 'Group')
                          : ApiService.displayName(
                              p['client'] is Map ? Map<dynamic, dynamic>.from(p['client'] as Map) : null,
                              fallback: 'Client',
                            );
                      final days = p['days'] as List<dynamic>? ?? [];
                      final planSummary = p['summary'] as Map<String, dynamic>? ?? {};
                      final workoutTitle = p['workoutTemplate']?['title']?.toString()
                          ?? () {
                            for (final d in days) {
                              if (d is! Map) continue;
                              final t = d['workoutTemplate']?['title']?.toString();
                              if (t != null && t.isNotEmpty) return t;
                            }
                            return 'Workout';
                          }();
                      return Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        padding: const EdgeInsets.all(12),
                        decoration: CoachDashboardTheme.cardDecoration(widget.isDark),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['title']?.toString() ?? 'Weekly Plan', style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(assignee, style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white54 : Colors.grey)),
                            Text('Workout: $workoutTitle', style: const TextStyle(fontSize: 12, color: CoachDashboardTheme.primary, fontWeight: FontWeight.w600)),
                            if (parseApiDateOnly(p['weekStartDate']?.toString()) case final ws?)
                              Text('Week of ${formatWeekRange(ws)}', style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white38 : Colors.grey.shade600)),
                            const SizedBox(height: 8),
                            ...days.where((d) => d is Map && d['enabled'] == true && d['offDay'] != true).take(4).map((raw) {
                              final day = Map<String, dynamic>.from(raw as Map);
                              const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                              final i = day['dayOfWeek'] as int? ?? 0;
                              final ex = day['exercises'] as List<dynamic>? ?? [];
                              final names = ex.map((e) => e['name']).whereType<String>().take(3).join(', ');
                              final progress = day['progress'] as Map<String, dynamic>? ?? {};
                              final completions = progress['completions'] as List<dynamic>? ?? const [];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${labels[i.clamp(0, 6)]}: ${names.isEmpty ? '${ex.length} exercise(s)' : names}${ex.length > 3 ? '…' : ''}',
                                      style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white70 : Colors.black87),
                                    ),
                                    if (completions.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8, top: 2),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 2,
                                          children: completions.map((raw) {
                                            final completion = Map<String, dynamic>.from(raw as Map);
                                            final user = completion['user'] is Map
                                                ? Map<dynamic, dynamic>.from(completion['user'] as Map)
                                                : null;
                                            final name = ApiService.displayName(user, fallback: 'Member');
                                            final status = completion['status']?.toString() ?? 'pending';
                                            return Text(
                                              '$name: ${status == 'completed' ? '✓ approved' : (status == 'pending_review' ? 'pending review' : (status == 'missed' ? 'missed' : 'assigned'))}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: status == 'completed'
                                                    ? CoachDashboardTheme.success
                                                    : (status == 'missed'
                                                        ? CoachDashboardTheme.danger
                                                        : (status == 'pending_review'
                                                            ? CoachDashboardTheme.warning
                                                            : Colors.orange)),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(7, (i) {
                                final day = days.cast<Map>().firstWhere((d) => d['dayOfWeek'] == i, orElse: () => {'enabled': false, 'offDay': false});
                                final offDay = day['offDay'] == true;
                                final enabled = day['enabled'] == true && !offDay;
                                final prog = day['progress'] as Map<String, dynamic>? ?? {};
                                final done = (prog['completed'] as int? ?? 0) > 0;
                                final missed = (prog['missed'] as int? ?? 0) > 0;
                                const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                                return Column(
                                  children: [
                                    Text(labels[i], style: const TextStyle(fontSize: 10)),
                                    const SizedBox(height: 4),
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: offDay
                                          ? Colors.blueGrey.withValues(alpha: 0.25)
                                          : !enabled
                                              ? Colors.grey.withValues(alpha: 0.2)
                                              : (done
                                                  ? CoachDashboardTheme.success.withValues(alpha: 0.2)
                                                  : (missed ? CoachDashboardTheme.danger.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2))),
                                      child: Text(
                                        offDay ? 'O' : (enabled ? (done ? '✓' : (missed ? '!' : '·')) : '-'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: offDay
                                              ? Colors.blueGrey.shade700
                                              : (done ? CoachDashboardTheme.success : (missed ? CoachDashboardTheme.danger : Colors.orange)),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${planSummary['completed'] ?? 0} done · ${planSummary['pending'] ?? 0} pending · ${planSummary['missed'] ?? 0} missed',
                              style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white54 : Colors.grey),
                            ),
                            Wrap(
                              spacing: 4,
                              children: [
                                TextButton.icon(
                                  onPressed: () => showCoachWorkoutDetailSheet(
                                    context,
                                    kind: CoachWorkoutDetailKind.weeklyPlan,
                                    data: p,
                                  ),
                                  icon: const Icon(Icons.visibility_outlined, size: 16),
                                  label: const Text('View'),
                                ),
                                TextButton.icon(onPressed: () => widget.onEditWeekly(p), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit')),
                                TextButton.icon(
                                  onPressed: () => widget.onDeleteWeekly(p),
                                  icon: const Icon(Icons.delete_outline, size: 16, color: CoachDashboardTheme.danger),
                                  label: const Text('Delete', style: TextStyle(color: CoachDashboardTheme.danger)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: _displayWeeklyPlans.length,
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Single Schedules', style: CoachDashboardTheme.sectionTitle(widget.isDark)),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _SearchField(isDark: widget.isDark, hint: 'Search single schedules', onChanged: (v) => setState(() => _query = v)),
              ),
              if (_displaySchedules.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    child: CoachDashboardTheme.emptyState(
                      icon: Icons.event_note_rounded,
                      message: _displayWeeklyPlans.isEmpty ? 'No schedules yet' : 'No single schedules — use Weekly Plans above',
                      isDark: widget.isDark,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final s = Map<String, dynamic>.from(_displaySchedules[index] as Map);
                        final isGroup = s['fitnessClass'] != null;
                        final assignee = isGroup
                            ? (s['fitnessClass']?['title'] as String?) ?? 'Group'
                            : ApiService.displayName(
                                s['client'] is Map ? Map<dynamic, dynamic>.from(s['client'] as Map) : null,
                                fallback: 'Client',
                              );
                        final title = s['title'] as String? ?? s['workoutTemplate']?['title'] as String? ?? 'Workout';
                        final progress = s['progress'] as Map<String, dynamic>?;
                        final fromWeekly = s['weeklyPlan'] != null;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: CoachDashboardTheme.cardDecoration(widget.isDark),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                                  if (fromWeekly)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: CoachDashboardTheme.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('Weekly', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: CoachDashboardTheme.primary)),
                                    ),
                                ],
                              ),
                              Text('${isGroup ? 'Group' : 'User'}: $assignee', style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white54 : Colors.grey)),
                              Text(_formatRange(s), style: const TextStyle(fontSize: 12, color: CoachDashboardTheme.primary)),
                              if ((s['notes'] as String? ?? '').isNotEmpty)
                                Padding(padding: const EdgeInsets.only(top: 6), child: Text(s['notes'].toString(), style: const TextStyle(fontSize: 12))),
                              if (progress != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '${progress['completed'] ?? 0} completed · ${progress['pending'] ?? 0} pending · ${progress['missed'] ?? 0} missed',
                                  style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white54 : Colors.grey),
                                ),
                                if ((progress['completions'] as List<dynamic>? ?? const []).isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Wrap(
                                      spacing: 10,
                                      runSpacing: 3,
                                      children: (progress['completions'] as List<dynamic>).map((raw) {
                                        final completion = Map<String, dynamic>.from(raw as Map);
                                        final user = completion['user'] is Map
                                            ? Map<dynamic, dynamic>.from(completion['user'] as Map)
                                            : null;
                                        final name = ApiService.displayName(user, fallback: 'Member');
                                        final status = completion['status']?.toString() ?? 'pending';
                                        return Text(
                                          '$name: ${status == 'completed' ? '✓ approved' : (status == 'pending_review' ? 'pending review' : (status == 'missed' ? 'missed' : 'assigned'))}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: status == 'completed'
                                                ? CoachDashboardTheme.success
                                                : (status == 'missed'
                                                    ? CoachDashboardTheme.danger
                                                    : (status == 'pending_review'
                                                        ? CoachDashboardTheme.warning
                                                        : Colors.orange)),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                              Wrap(
                                spacing: 4,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => showCoachWorkoutDetailSheet(
                                      context,
                                      kind: CoachWorkoutDetailKind.schedule,
                                      data: s,
                                    ),
                                    icon: const Icon(Icons.visibility_outlined, size: 16),
                                    label: const Text('View'),
                                  ),
                                  TextButton.icon(onPressed: () => widget.onEdit(s), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit')),
                                  TextButton.icon(
                                    onPressed: () => _deleteSchedule(s['_id'].toString()),
                                    icon: const Icon(Icons.delete_outline, size: 16, color: CoachDashboardTheme.danger),
                                    label: const Text('Delete', style: TextStyle(color: CoachDashboardTheme.danger)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: _displaySchedules.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final bool isDark;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.isDark, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        onChanged: onChanged,
        decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Search', hint: hint).copyWith(
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
        ),
      ),
    );
  }
}

class _ProgressSummaryCard extends StatelessWidget {
  final bool isDark;
  final int completed;
  final int pending;
  final int missed;
  final int percent;

  const _ProgressSummaryCard({
    required this.isDark,
    required this.completed,
    required this.pending,
    required this.missed,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CoachDashboardTheme.primary.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CoachDashboardTheme.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Completion tracking', style: TextStyle(fontWeight: FontWeight.w700, color: CoachDashboardTheme.primary)),
              const Spacer(),
              Text('$percent%', style: const TextStyle(fontWeight: FontWeight.bold, color: CoachDashboardTheme.primary)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: percent / 100, minHeight: 6, color: CoachDashboardTheme.primary, backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200),
          ),
          const SizedBox(height: 8),
          Text('$completed completed · $pending pending · $missed missed', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
        ],
      ),
    );
  }
}
