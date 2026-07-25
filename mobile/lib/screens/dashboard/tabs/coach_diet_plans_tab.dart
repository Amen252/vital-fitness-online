import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/diet_plan_completion_model.dart';
import '../../../models/diet_plan_model.dart';
import '../../../models/diet_today_progress_model.dart';
import '../../../services/api_service.dart';
import '../../../widgets/diet_progress_panel.dart';
import '../../../widgets/scrollable_body.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';

class CoachDietPlansTab extends StatefulWidget {
  const CoachDietPlansTab({super.key});

  @override
  State<CoachDietPlansTab> createState() => _CoachDietPlansTabState();
}

Map<String, dynamic> _asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected a diet plan object, got ${value.runtimeType}');
}

class _CoachDietPlansTabState extends State<CoachDietPlansTab> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final _searchCtrl = TextEditingController();
  late TabController _mainTabs;

  bool _loading = true;
  String _error = '';
  List<DietPlan> _plans = [];
  int _page = 1;
  int _totalPages = 1;
  String _statusFilter = 'all';
  String _assigneeFilter = 'all';
  String _sort = 'newest';

  bool _completionLoading = false;
  String _completionError = '';
  String _completionFilter = 'all';
  List<DietPlanCompletion> _completions = [];
  int _completedCount = 0;
  int _notCompletedCount = 0;

  @override
  void initState() {
    super.initState();
    _mainTabs = TabController(length: 2, vsync: this);
    _mainTabs.addListener(_onMainTabChanged);
    _load();
    _loadCompletions();
  }

  void _onMainTabChanged() {
    if (_mainTabs.index == 1 && !_mainTabs.indexIsChanging) {
      _loadCompletions();
    }
  }

  @override
  void dispose() {
    _mainTabs.removeListener(_onMainTabChanged);
    _mainTabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCompletions() async {
    setState(() {
      _completionLoading = true;
      _completionError = '';
    });
    try {
      final data = await _api.getDietPlanCompletions(status: _completionFilter);
      if (!mounted) return;
      setState(() {
        _completions = (data['users'] as List<dynamic>? ?? [])
            .map((u) => DietPlanCompletion.fromJson(Map<String, dynamic>.from(u as Map)))
            .toList();
        _completedCount = (data['completedCount'] as num?)?.toInt() ?? 0;
        _notCompletedCount = (data['notCompletedCount'] as num?)?.toInt() ?? 0;
        _completionLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _completionError = ApiService.friendlyError(e);
          _completionLoading = false;
        });
      }
    }
  }

  void _refreshCurrentTab() {
    if (_mainTabs.index == 0) {
      _load();
    } else {
      _loadCompletions();
    }
  }

  Future<void> _load({int? page}) async {
    setState(() {
      _loading = true;
      _error = '';
      if (page != null) _page = page;
    });
    try {
      final data = await _api.getCoachDietPlans(
        search: _searchCtrl.text.trim(),
        status: _statusFilter,
        assigneeType: _assigneeFilter,
        sort: _sort,
        page: _page,
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _plans = (data['plans'] as List<dynamic>? ?? [])
            .map((p) => DietPlan.fromJson(_asJsonMap(p)))
            .toList();
        _totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.friendlyError(e); _loading = false; });
    }
  }

  void _openCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CoachDietPlanEditorScreen(createMode: true),
      ),
    ).then((saved) async {
      if (saved != true || !mounted) return;
      await _load(page: 1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diet plan created and sent successfully.'),
          backgroundColor: CoachDashboardTheme.success,
        ),
      );
    });
  }

  void _openPlan(DietPlan plan, {required bool viewOnly}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoachDietPlanEditorScreen(
          planId: plan.id,
          clientId: plan.clientId,
          fitnessClassId: plan.fitnessClassId,
          assigneeName: plan.displayAssigneeName,
          viewOnly: viewOnly,
        ),
      ),
    ).then((saved) async {
      if (saved != true || !mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diet plan updated and sent successfully.'),
          backgroundColor: CoachDashboardTheme.success,
        ),
      );
    });
  }

  Future<void> _deletePlan(DietPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete diet plan?'),
        content: Text('Remove "${plan.title}" for ${plan.displayAssigneeName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CoachDashboardTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || plan.id == null) return;
    try {
      await _api.archiveDietPlan(plan.id!);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Diet plan deleted.'), backgroundColor: CoachDashboardTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: CoachDashboardTheme.danger),
        );
      }
    }
  }

  Future<void> _sendAgain(DietPlan plan) async {
    if (plan.id == null) return;
    try {
      await _api.sendDietPlanAgain(plan.id!);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Diet plan sent again.'), backgroundColor: CoachDashboardTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: CoachDashboardTheme.danger),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'draft':
        return CoachDashboardTheme.warning;
      case 'completed':
      case 'archived':
        return CoachDashboardTheme.textSecondary;
      default:
        return CoachDashboardTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CoachPage(
      title: 'Diet Plans',
      centerTitle: false,
      actions: [
        TextButton.icon(
          onPressed: _openCreate,
          icon: const Icon(Icons.add_rounded, color: CoachDashboardTheme.primary),
          label: const Text('Create Diet Plan', style: TextStyle(color: CoachDashboardTheme.primary, fontWeight: FontWeight.w600)),
        ),
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _refreshCurrentTab),
      ],
      bottom: TabBar(
        controller: _mainTabs,
        labelColor: CoachDashboardTheme.primary,
        indicatorColor: CoachDashboardTheme.primary,
        unselectedLabelColor: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
        tabs: const [
          Tab(text: 'Plans'),
          Tab(text: 'User Completion'),
        ],
      ),
      body: TabBarView(
        controller: _mainTabs,
        children: [
          _buildPlansTab(isDark),
          _buildCompletionTab(isDark),
        ],
      ),
    );
  }

  Widget _buildPlansTab(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Search plans').copyWith(
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search_rounded),
                    onPressed: () => _load(page: 1),
                  ),
                ),
                onSubmitted: (_) => _load(page: 1),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('All', 'all', isDark),
                    _filterChip('Active', 'active', isDark),
                    _filterChip('Draft', 'draft', isDark),
                    _filterChip('History', 'completed', isDark),
                    const SizedBox(width: 8),
                    Container(width: 1, height: 24, color: isDark ? Colors.white24 : Colors.black12),
                    const SizedBox(width: 8),
                    _assigneeChip('Everyone', 'all', isDark),
                    _assigneeChip('By User', 'user', isDark),
                    _assigneeChip('By Group', 'group', isDark),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _sort,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'newest', child: Text('Newest first')),
                        DropdownMenuItem(value: 'oldest', child: Text('Oldest first')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _sort = v);
                        _load(page: 1);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody(isDark)),
      ],
    );
  }

  Widget _buildCompletionTab(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_completedCount completed · $_notCompletedCount pending',
                style: CoachDashboardTheme.bodyMuted(isDark),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _completionFilterChip('All', 'all', isDark),
                    _completionFilterChip('Completed', 'completed', isDark),
                    _completionFilterChip('Not Completed', 'not_completed', isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildCompletionBody(isDark)),
      ],
    );
  }

  Widget _completionFilterChip(String label, String value, bool isDark) {
    final selected = _completionFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _completionFilter = value);
          _loadCompletions();
        },
        selectedColor: CoachDashboardTheme.primary.withValues(alpha: 0.15),
        checkmarkColor: CoachDashboardTheme.primary,
      ),
    );
  }

  Widget _buildCompletionBody(bool isDark) {
    if (_completionLoading) {
      return const Center(child: CircularProgressIndicator(color: CoachDashboardTheme.primary));
    }
    if (_completionError.isNotEmpty) {
      return Center(child: Text(_completionError, textAlign: TextAlign.center));
    }
    if (_completions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, size: 48, color: isDark ? Colors.white24 : Colors.grey),
            const SizedBox(height: 12),
            const Text('No assigned users with active diet plans'),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: dashboardScrollPhysics,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: _completions.length,
      itemBuilder: (context, i) => _completionCard(_completions[i], isDark),
    );
  }

  Widget _completionCard(DietPlanCompletion item, bool isDark) {
    final statusColor = item.completed ? CoachDashboardTheme.success : CoachDashboardTheme.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Text(item.statusIcon, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(item.planName, style: CoachDashboardTheme.bodyMuted(isDark)),
                      if (item.groupName != null) Text('Group: ${item.groupName}', style: CoachDashboardTheme.bodyMuted(isDark)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(item.dailyProgressLabel, style: TextStyle(fontWeight: FontWeight.w600, color: statusColor)),
            const SizedBox(height: 6),
            Text('Weekly average: ${item.weeklyAveragePercent}%', style: CoachDashboardTheme.bodyMuted(isDark)),
            const SizedBox(height: 10),
            ...item.meals.map((meal) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${meal.statusIcon} ${meal.statusText}',
                    style: TextStyle(
                      fontSize: 13,
                      color: meal.completed ? CoachDashboardTheme.success : CoachDashboardTheme.danger,
                    ),
                  ),
                )),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (item.progressPercent / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value, bool isDark) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _statusFilter = value);
          _load(page: 1);
        },
        selectedColor: CoachDashboardTheme.primary.withValues(alpha: 0.15),
        checkmarkColor: CoachDashboardTheme.primary,
      ),
    );
  }

  Widget _assigneeChip(String label, String value, bool isDark) {
    final selected = _assigneeFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _assigneeFilter = value);
          _load(page: 1);
        },
        selectedColor: CoachDashboardTheme.accent.withValues(alpha: 0.15),
        checkmarkColor: CoachDashboardTheme.accent,
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: CoachDashboardTheme.primary));
    }
    if (_error.isNotEmpty) {
      return Center(child: Text(_error, textAlign: TextAlign.center));
    }
    if (_plans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restaurant_menu_rounded, size: 48, color: isDark ? Colors.white24 : Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No diet plans yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : CoachDashboardTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a plan and assign it to an approved client or class.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: CoachDashboardTheme.primaryButtonStyle(),
                onPressed: _openCreate,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text('Create Diet Plan', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            physics: dashboardScrollPhysics,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            itemCount: _plans.length,
            itemBuilder: (context, i) => _planCard(_plans[i], isDark),
          ),
        ),
        if (_totalPages > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _page > 1 ? () => _load(page: _page - 1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text('Page $_page of $_totalPages'),
                IconButton(
                  onPressed: _page < _totalPages ? () => _load(page: _page + 1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _planCard(DietPlan plan, bool isDark) {
    final created = plan.createdAt != null ? DateFormat('MMM d, yyyy').format(plan.createdAt!) : '—';
    final statusColor = _statusColor(plan.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        title: Text(plan.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              plan.isGroupPlan
                  ? 'By Group: ${plan.displayAssigneeName}'
                  : 'By User: ${plan.displayAssigneeName}',
            ),
            Text('Created: $created'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: CoachDashboardTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: CoachDashboardTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    plan.planTypeLabel,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CoachDashboardTheme.primary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(plan.statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    plan.isGroupPlan ? 'Group' : 'User',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case 'view':
                _openPlan(plan, viewOnly: true);
              case 'edit':
                _openPlan(plan, viewOnly: false);
              case 'send':
                _sendAgain(plan);
              case 'delete':
                _deletePlan(plan);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'view', child: Text('View')),
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'send', child: Text('Send Again')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => _openPlan(plan, viewOnly: true),
      ),
    );
  }
}

class CoachDietPlanEditorScreen extends StatefulWidget {
  final String? planId;
  final String? clientId;
  final String? fitnessClassId;
  final String? assigneeName;
  final int? memberCount;
  final bool createMode;
  final bool viewOnly;

  const CoachDietPlanEditorScreen({
    super.key,
    this.planId,
    this.clientId,
    this.fitnessClassId,
    this.assigneeName,
    this.memberCount,
    this.createMode = false,
    this.viewOnly = false,
  });

  @override
  State<CoachDietPlanEditorScreen> createState() => _CoachDietPlanEditorScreenState();
}

class _CoachDietPlanEditorScreenState extends State<CoachDietPlanEditorScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabs;
  bool _loading = true;
  bool _saving = false;
  DietPlan? _plan;
  DietTodayProgress _todayProgress = const DietTodayProgress();
  int _avgAdherence = 0;
  bool _progressLoading = false;
  List<Map<String, dynamic>> _groupMembers = [];
  List<String> _progressMealTypes = [];
  final Map<String, bool> _progressMealFollowed = {};

  String? _selectedClientId;
  String? _selectedClassId;
  String? _selectedAssigneeName;
  List<dynamic> _clients = [];
  List<dynamic> _classes = [];
  String _assigneeType = 'user';

  String? get _clientId => _selectedClientId ?? widget.clientId;
  String? get _fitnessClassId => _selectedClassId ?? widget.fitnessClassId;
  bool get _isGroup => _fitnessClassId != null;

  final _titleCtrl = TextEditingController(text: 'Diet Plan');
  final _caloriesCtrl = TextEditingController(text: '2000');
  final _notesCtrl = TextEditingController();
  String _goal = 'maintenance';
  String _planType = 'single_day'; // single_day | weekly
  int _selectedDay = 0; // Monday-based — day being edited (weekly)
  final Set<int> _enabledDays = <int>{}; // weekly days included via checkboxes
  int? _singleDayIndex; // single_day: which weekday is checked

  final List<_DayMealsBucket> _dayBuckets = List.generate(7, (_) => _DayMealsBucket());
  _DayMealsBucket get _activeBucket =>
      _planType == 'weekly' ? _dayBuckets[_selectedDay.clamp(0, 6)] : _dayBuckets[0];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: widget.createMode ? 1 : 2, vsync: this);
    if (!widget.createMode) {
      _tabs.addListener(_onTabChanged);
    }
    _selectedClientId = widget.clientId;
    _selectedClassId = widget.fitnessClassId;
    _selectedAssigneeName = widget.assigneeName;
    _singleDayIndex = DietDay.mondayBasedDayOfWeek();
    if (_isGroup && widget.assigneeName != null) {
      _titleCtrl.text = '${widget.assigneeName} Diet Plan';
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.createMode && widget.clientId == null && widget.fitnessClassId == null) {
      await _loadAssignees();
    }
    await _load();
  }

  Future<void> _loadAssignees() async {
    try {
      final results = await Future.wait([_api.getCoachClients(), _api.getCoachClasses()]);
      if (mounted) {
        setState(() {
          _clients = results[0];
          _classes = results[1];
        });
      }
    } catch (_) {}
  }

  void _onTabChanged() {
    if (_tabs.index == 1 && !_tabs.indexIsChanging) {
      _refreshProgress();
    }
  }

  void _applyProgressData(Map<String, dynamic>? data) {
    if (data == null) return;
    _avgAdherence = (data['avgAdherence'] as num?)?.toInt() ?? 0;
    final todayJson = data['today'] as Map<String, dynamic>?;
    _todayProgress = DietTodayProgress.fromJson(todayJson);

    final plannedFromApi = (data['plannedMealTypes'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList()
        ?? (todayJson?['plannedMealTypes'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList()
        ?? const <String>[];
    final plannedFromPlan = _plan?.mealsForDay()
            .where((m) => m.hasContent)
            .map((m) => m.type)
            .toSet()
            .toList()
        ?? const <String>[];
    _progressMealTypes = plannedFromApi.isNotEmpty ? plannedFromApi : plannedFromPlan;

    _progressMealFollowed
      ..clear()
      ..addEntries(
        _todayProgress.mealAdherence.map((entry) {
          final type = entry['type']?.toString() ?? '';
          return MapEntry(type, entry['followed'] == true);
        }).where((e) => e.key.isNotEmpty),
      );

    final members = data['members'] as List<dynamic>? ?? const [];
    _groupMembers = members
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    if (_plan != null && _todayProgress.targetCalories == 0) {
      final plannedMeals = _progressMealTypes.isNotEmpty
          ? _progressMealTypes.length
          : _plan!.meals.where((m) => m.name.isNotEmpty || m.description.isNotEmpty).length;
      _todayProgress = DietTodayProgress(
        caloriesConsumed: _todayProgress.caloriesConsumed,
        targetCalories: _plan!.dailyCalories,
        waterMl: _todayProgress.waterMl,
        targetWaterMl: _todayProgress.targetWaterMl,
        mealsCompleted: _todayProgress.mealsCompleted,
        mealsPlanned: _todayProgress.mealsPlanned > 0 ? _todayProgress.mealsPlanned : plannedMeals,
        workoutsCompleted: _todayProgress.workoutsCompleted,
        workoutsPlanned: _todayProgress.workoutsPlanned,
        dailyGoalPercent: _todayProgress.dailyGoalPercent,
        adherencePercent: _todayProgress.adherencePercent,
        followedPlan: _todayProgress.followedPlan,
        hasActivity: _todayProgress.hasActivity,
        mealAdherence: _todayProgress.mealAdherence,
        weeklyAveragePercent: _todayProgress.weeklyAveragePercent,
      );
    }
  }

  Future<void> _refreshProgress() async {
    if (widget.createMode) return;
    setState(() => _progressLoading = true);
    try {
      if (_plan?.clientId != null) {
        final data = await _api.getClientDietProgress(
          _plan!.clientId!,
          planId: widget.planId ?? _plan?.id,
        );
        if (mounted) setState(() => _applyProgressData(Map<String, dynamic>.from(data as Map)));
      } else if (_plan?.fitnessClassId != null) {
        final data = await _api.getGroupDietProgress(_plan!.fitnessClassId!);
        if (mounted) {
          setState(() {
            _applyProgressData(Map<String, dynamic>.from(data as Map));
            _avgAdherence = (data['avgAdherence'] as num?)?.toInt() ?? _avgAdherence;
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _progressLoading = false);
  }

  @override
  void dispose() {
    if (!widget.createMode) {
      _tabs.removeListener(_onTabChanged);
    }
    _tabs.dispose();
    _titleCtrl.dispose();
    _caloriesCtrl.dispose();
    _notesCtrl.dispose();
    for (final bucket in _dayBuckets) {
      bucket.dispose();
    }
    super.dispose();
  }

  void _resetForm() {
    _plan = null;
    _titleCtrl.text = 'Diet Plan';
    _caloriesCtrl.text = '2000';
    _notesCtrl.clear();
    _goal = 'maintenance';
    _planType = 'single_day';
    _selectedDay = 0;
    _enabledDays.clear();
    _singleDayIndex = DietDay.mondayBasedDayOfWeek();
    for (final bucket in _dayBuckets) {
      bucket.clear();
    }
    if (!widget.createMode) return;
    setState(() {
      _selectedClientId = null;
      _selectedClassId = null;
      _selectedAssigneeName = null;
      _assigneeType = 'user';
    });
  }

  Future<void> _load() async {
    if (widget.planId != null) {
      setState(() => _loading = true);
      try {
        final planJson = await _api.getDietPlanById(widget.planId!);
        _plan = DietPlan.fromJson(planJson);
        _applyPlan(_plan!);
        if (!widget.createMode && _plan!.clientId != null) {
          final progressData = await _api.getClientDietProgress(
            _plan!.clientId!,
            planId: widget.planId ?? _plan!.id,
          );
          _applyProgressData(Map<String, dynamic>.from(progressData as Map));
        } else if (!widget.createMode && _plan!.fitnessClassId != null) {
          final progressData = await _api.getGroupDietProgress(_plan!.fitnessClassId!);
          _applyProgressData(Map<String, dynamic>.from(progressData as Map));
        }
      } catch (_) {}
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (_clientId == null && _fitnessClassId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _isGroup
            ? _api.getGroupDietPlan(_fitnessClassId!)
            : _api.getClientDietPlan(_clientId!),
        _isGroup
            ? _api.getGroupDietProgress(_fitnessClassId!)
            : _api.getClientDietProgress(_clientId!, planId: _plan?.id),
      ]);
      final planJson = results[0];
      final progressJson = results[1] as Map<String, dynamic>;
      if (planJson != null) {
        _plan = DietPlan.fromJson(planJson);
        _applyPlan(_plan!);
      }
      _applyProgressData(progressJson);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyPlan(DietPlan plan) {
    _titleCtrl.text = plan.title;
    _caloriesCtrl.text = '${plan.dailyCalories}';
    _notesCtrl.text = plan.notes;
    _goal = plan.goal;
    _planType = plan.isWeekly ? 'weekly' : 'single_day';
    _selectedDay = plan.todayDayOfWeek ?? DietDay.mondayBasedDayOfWeek();
    _enabledDays.clear();
    _singleDayIndex = plan.targetDayOfWeek ?? DietDay.mondayBasedDayOfWeek();
    for (final bucket in _dayBuckets) {
      bucket.clear();
    }
    if (plan.isWeekly && plan.days.isNotEmpty) {
      for (final day in plan.days) {
        if (day.dayOfWeek >= 0 && day.dayOfWeek <= 6) {
          _dayBuckets[day.dayOfWeek].loadFromMeals(day.meals);
          if (day.meals.any((m) => m.hasContent)) {
            _enabledDays.add(day.dayOfWeek);
          }
        }
      }
      if (_enabledDays.isNotEmpty && !_enabledDays.contains(_selectedDay)) {
        _selectedDay = _enabledDays.first;
      }
    } else {
      _dayBuckets[0].loadFromMeals(plan.meals);
    }
  }

  void _togglePlanType(String type) {
    if (_planType == type) return;
    setState(() {
      _planType = type;
      final today = DietDay.mondayBasedDayOfWeek();
      if (type == 'weekly') {
        if (_enabledDays.isEmpty) {
          _enabledDays.add(today);
        }
        _selectedDay = _enabledDays.contains(today) ? today : _enabledDays.first;
      } else {
        _singleDayIndex ??= today;
      }
    });
  }

  void _setSingleDay(int dayIndex) {
    setState(() => _singleDayIndex = dayIndex);
  }

  void _toggleDayEnabled(int dayIndex, bool enabled) {
    setState(() {
      if (enabled) {
        _enabledDays.add(dayIndex);
        _selectedDay = dayIndex;
      } else {
        _enabledDays.remove(dayIndex);
        _dayBuckets[dayIndex].clear();
        if (_selectedDay == dayIndex) {
          _selectedDay = _enabledDays.isEmpty ? 0 : _enabledDays.first;
        }
      }
    });
  }

  bool _isPresetSnackSelected(String name) {
    return _activeBucket.snackForms.any((f) => f.name.text.trim() == name);
  }

  List<_MealForm> get _customSnackForms {
    return _activeBucket.snackForms.where((f) => !_snackOptions.contains(f.name.text.trim())).toList();
  }

  void _togglePresetSnack(String name, bool selected) {
    setState(() {
      final bucket = _activeBucket;
      if (selected) {
        if (!bucket.snackForms.any((f) => f.name.text.trim() == name)) {
          final form = _MealForm();
          form.name.text = name;
          bucket.snackForms.add(form);
        }
      } else {
        final index = bucket.snackForms.indexWhere((f) => f.name.text.trim() == name);
        if (index != -1) {
          bucket.snackForms[index].dispose();
          bucket.snackForms.removeAt(index);
        }
      }
    });
  }

  void _addSnack({String? presetName}) {
    setState(() {
      final form = _MealForm();
      if (presetName != null) form.name.text = presetName;
      _activeBucket.snackForms.add(form);
    });
  }

  void _removeSnack(_MealForm form) {
    setState(() {
      final list = _activeBucket.snackForms;
      final index = list.indexOf(form);
      if (index == -1) return;
      list[index].dispose();
      list.removeAt(index);
    });
  }

  bool get _hasAssignee => _clientId != null || _fitnessClassId != null;

  Future<void> _save({required String status}) async {
    if (!_hasAssignee) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a user or group first.'), backgroundColor: CoachDashboardTheme.warning),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        if (_plan?.id != null) 'planId': _plan!.id,
        if (_isGroup) 'fitnessClassId': _fitnessClassId,
        if (!_isGroup) 'clientId': _clientId,
        'title': _titleCtrl.text.trim(),
        'goal': _goal,
        'planType': _planType,
        'dailyCalories': int.tryParse(_caloriesCtrl.text) ?? 2000,
        'notes': _notesCtrl.text.trim(),
        'status': status,
      };
      if (_planType == 'weekly') {
        if (_enabledDays.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Check at least one day for the weekly plan.'),
              backgroundColor: CoachDashboardTheme.warning,
            ),
          );
          setState(() => _saving = false);
          return;
        }
        payload['days'] = List.generate(7, (i) => {
              'dayOfWeek': i,
              'meals': _enabledDays.contains(i)
                  ? _dayBuckets[i].buildMeals().map((m) => m.toJson()).toList()
                  : <Map<String, dynamic>>[],
            });
      } else {
        if (_singleDayIndex == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Check one day for the single-day plan.'),
              backgroundColor: CoachDashboardTheme.warning,
            ),
          );
          setState(() => _saving = false);
          return;
        }
        payload['targetDayOfWeek'] = _singleDayIndex;
        payload['meals'] = _dayBuckets[0].buildMeals().map((m) => m.toJson()).toList();
      }
      await _api.createDietPlan(payload);
      if (!mounted) return;

      final sent = status == 'active';

      // Create/Send and Save/Send: close editor and let the list refresh + toast.
      if (sent && (widget.createMode || widget.planId != null)) {
        Navigator.pop(context, true);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved.'),
          backgroundColor: CoachDashboardTheme.success,
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: CoachDashboardTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendReminders() async {
    final clientId = _clientId;
    final classId = _fitnessClassId;
    if (clientId == null && classId == null) return;
    try {
      final res = classId != null
          ? await _api.sendGroupMealReminders(classId)
          : await _api.sendMealReminders(clientId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Reminders sent'), backgroundColor: CoachDashboardTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: CoachDashboardTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.createMode
        ? 'Create Diet Plan'
        : (widget.assigneeName ?? _selectedAssigneeName ?? 'Diet Plan');
    final readOnly = widget.viewOnly;

    return CoachPage(
      title: title,
      bottom: widget.createMode
          ? null
          : TabBar(
              controller: _tabs,
              labelColor: CoachDashboardTheme.primary,
              indicatorColor: CoachDashboardTheme.primary,
              unselectedLabelColor: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
              tabs: const [Tab(text: 'Plan'), Tab(text: 'Progress')],
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : widget.createMode
              ? _buildPlanForm(isDark, readOnly: readOnly)
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _buildPlanForm(isDark, readOnly: readOnly),
                    _buildProgressTab(isDark),
                  ],
                ),
    );
  }

  Widget _buildAssigneePicker(bool isDark, {required bool readOnly}) {
    if (!widget.createMode || (widget.clientId != null || widget.fitnessClassId != null)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Assign To', style: CoachDashboardTheme.sectionTitle(isDark)),
        const SizedBox(height: 4),
        Text(
          'Create a personal plan for one client, or one plan for an entire group.',
          style: CoachDashboardTheme.bodyMuted(isDark),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'user', label: Text('By User'), icon: Icon(Icons.person_outline_rounded)),
            ButtonSegment(value: 'group', label: Text('By Group'), icon: Icon(Icons.groups_outlined)),
          ],
          selected: {_assigneeType},
          onSelectionChanged: readOnly
              ? null
              : (selection) => setState(() {
                    _assigneeType = selection.first;
                    _selectedClientId = null;
                    _selectedClassId = null;
                    _selectedAssigneeName = null;
                  }),
        ),
        const SizedBox(height: 10),
        if (_assigneeType == 'user')
          DropdownButtonFormField<String>(
            value: _selectedClientId,
            decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Select Client'),
            items: _clients.map((c) {
              final id = c['user']?['_id']?.toString() ?? '';
              final userMap = c['user'] is Map ? Map<dynamic, dynamic>.from(c['user'] as Map) : null;
              final name = ApiService.displayName(userMap, fallback: 'Client');
              return DropdownMenuItem(value: id, child: Text(name));
            }).toList(),
            onChanged: readOnly
                ? null
                : (v) => setState(() {
                      _selectedClientId = v;
                      final match = _clients
                          .map((c) => c['user'])
                          .whereType<Map>()
                          .cast<Map>()
                          .where((u) => u['_id']?.toString() == v)
                          .toList();
                      _selectedAssigneeName = match.isEmpty
                          ? 'Client'
                          : ApiService.displayName(
                              Map<dynamic, dynamic>.from(match.first),
                              fallback: 'Client',
                            );
                    }),
          )
        else
          DropdownButtonFormField<String>(
            value: _selectedClassId,
            decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Select Group'),
            items: _classes.map((cls) {
              final id = cls['_id']?.toString() ?? '';
              final name = cls['title']?.toString() ?? 'Group';
              final count = cls['enrolledCount'] as int? ?? (cls['enrolledStudents'] as List?)?.length ?? 0;
              return DropdownMenuItem(value: id, child: Text('$name ($count members)'));
            }).toList(),
            onChanged: readOnly
                ? null
                : (v) => setState(() {
                      _selectedClassId = v;
                      _selectedAssigneeName = _classes
                          .firstWhere((cls) => cls['_id']?.toString() == v, orElse: () => {'title': 'Group'})['title']
                          ?.toString();
                      if (_selectedAssigneeName != null) {
                        _titleCtrl.text = '$_selectedAssigneeName Diet Plan';
                      }
                    }),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPlanForm(bool isDark, {required bool readOnly}) {
    return ListView(
      physics: dashboardScrollPhysics,
      padding: const EdgeInsets.all(18),
      children: [
        _buildAssigneePicker(isDark, readOnly: readOnly),
        if (_isGroup && widget.memberCount != null)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CoachDashboardTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('This plan applies to all ${widget.memberCount} members in ${widget.assigneeName}.'),
          ),
        TextField(
          controller: _titleCtrl,
          readOnly: readOnly,
          decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Plan Title'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _goal,
          decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Goal'),
          items: const [
            DropdownMenuItem(value: 'weight_loss', child: Text('Weight Loss')),
            DropdownMenuItem(value: 'muscle_gain', child: Text('Muscle Gain')),
            DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
          ],
          onChanged: readOnly ? null : (v) => setState(() => _goal = v ?? 'maintenance'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _caloriesCtrl,
          readOnly: readOnly,
          keyboardType: TextInputType.number,
          decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Daily Calories'),
        ),
        const SizedBox(height: 16),
        Text('Plan type', style: CoachDashboardTheme.sectionTitle(isDark)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              CheckboxListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: CoachDashboardTheme.primary,
                value: _planType == 'single_day',
                title: const Text('Single Day Diet Plan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Check one day, then set Breakfast, Lunch, Dinner & Snacks', style: TextStyle(fontSize: 12)),
                onChanged: readOnly
                    ? null
                    : (v) {
                        if (v == true) _togglePlanType('single_day');
                      },
              ),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
              CheckboxListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: CoachDashboardTheme.primary,
                value: _planType == 'weekly',
                title: const Text('Weekly Diet Plan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Check days below and set meals for each', style: TextStyle(fontSize: 12)),
                onChanged: readOnly
                    ? null
                    : (v) {
                        if (v == true) _togglePlanType('weekly');
                      },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_planType == 'single_day') ...[
          Text('Day of the week', style: CoachDashboardTheme.sectionTitle(isDark)),
          const SizedBox(height: 4),
          Text(
            'Check the day this plan applies to.',
            style: CoachDashboardTheme.bodyMuted(isDark),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: CoachDashboardTheme.primary,
                    value: _singleDayIndex == i,
                    title: Text(
                      DietDay.dayNames[i],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _singleDayIndex == i ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      _singleDayIndex == i ? 'Selected day' : 'Tap to select',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey),
                    ),
                    onChanged: readOnly
                        ? null
                        : (v) {
                            if (v == true) _setSingleDay(i);
                          },
                  ),
                ],
              ],
            ),
          ),
          if (_singleDayIndex != null) ...[
            const SizedBox(height: 12),
            Text(
              'Meals for ${DietDay.dayNames[_singleDayIndex!]}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CoachDashboardTheme.primary),
            ),
          ],
        ],
        if (_planType == 'weekly') ...[
          Text('Days of the week', style: CoachDashboardTheme.sectionTitle(isDark)),
          const SizedBox(height: 4),
          Text(
            'Check each day to include it, then set Breakfast, Lunch, Dinner & Snacks.',
            style: CoachDashboardTheme.bodyMuted(isDark),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: CoachDashboardTheme.primary,
                    value: _enabledDays.contains(i),
                    selected: _enabledDays.contains(i) && _selectedDay == i,
                    title: Text(
                      DietDay.dayNames[i],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: (_enabledDays.contains(i) && _selectedDay == i)
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      _enabledDays.contains(i)
                          ? (_dayBuckets[i].buildMeals().isEmpty
                              ? 'Checked · add meals below'
                              : '${_dayBuckets[i].buildMeals().length} meal(s) · tap to edit')
                          : 'Not included',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey),
                    ),
                    secondary: _enabledDays.contains(i)
                        ? IconButton(
                            tooltip: 'Edit meals',
                            icon: Icon(
                              Icons.restaurant_menu_rounded,
                              color: _selectedDay == i ? CoachDashboardTheme.primary : null,
                            ),
                            onPressed: readOnly ? null : () => setState(() => _selectedDay = i),
                          )
                        : null,
                    onChanged: readOnly
                        ? null
                        : (v) => _toggleDayEnabled(i, v ?? false),
                  ),
                ],
              ],
            ),
          ),
          if (_enabledDays.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Meals for ${DietDay.dayNames[_selectedDay]}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CoachDashboardTheme.primary),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Check at least one day above to add meals.',
              style: TextStyle(fontSize: 12, color: CoachDashboardTheme.warning),
            ),
          ],
        ],
        if ((_planType == 'single_day' && _singleDayIndex != null) ||
            (_planType == 'weekly' && _enabledDays.contains(_selectedDay))) ...[
          const SizedBox(height: 8),
          ..._activeBucket.mealForms.entries.map((e) => _MealSection(
                label: e.key,
                form: e.value,
                isDark: isDark,
                readOnly: readOnly,
              )),
          _SnacksListSection(
            snackForms: _activeBucket.snackForms,
            customSnackForms: _customSnackForms,
            isDark: isDark,
            readOnly: readOnly,
            isPresetSelected: _isPresetSnackSelected,
            onTogglePreset: _togglePresetSnack,
            onAdd: _addSnack,
            onRemove: _removeSnack,
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _notesCtrl,
          readOnly: readOnly,
          maxLines: 3,
          decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Coach Notes'),
        ),
        if (!readOnly) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: CoachDashboardTheme.primaryButtonStyle(),
              onPressed: _saving ? null : () => _save(status: 'active'),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.createMode ? 'Create & Send Plan' : 'Save & Send Plan'),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _saving ? null : () => _save(status: 'draft'),
            child: const Text('Save as Draft'),
          ),
          if (!widget.createMode) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _sendReminders,
              icon: const Icon(Icons.alarm_rounded),
              label: Text(_isGroup ? 'Send Reminders to Group' : 'Send Meal Reminders'),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildProgressTab(bool isDark) {
    if (_progressLoading) {
      return const Center(child: CircularProgressIndicator(color: CoachDashboardTheme.primary));
    }

    final mealFollowed = Map<String, bool>.from(_progressMealFollowed);
    if (mealFollowed.isEmpty) {
      for (final entry in _todayProgress.mealAdherence) {
        final type = entry['type']?.toString() ?? '';
        if (type.isNotEmpty) mealFollowed[type] = entry['followed'] == true;
      }
    }

    return DietProgressPanel(
      today: _todayProgress,
      avgAdherence: _avgAdherence,
      mealTypes: _groupMembers.isEmpty ? _progressMealTypes : const [],
      mealFollowed: mealFollowed,
      isDark: isDark,
      onRefresh: _refreshProgress,
      footer: [
        if (_groupMembers.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Member meal completion today', style: CoachDashboardTheme.sectionTitle(isDark)),
          const SizedBox(height: 8),
          ..._groupMembers.map((member) {
            final name = member['name']?.toString() ?? 'Member';
            final meals = (member['mealAdherence'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList();
            final planned = _progressMealTypes.isNotEmpty
                ? _progressMealTypes
                : meals.map((m) => m['type']?.toString() ?? '').where((t) => t.isNotEmpty).toList();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: CoachDashboardTheme.cardDecoration(isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  if (planned.isEmpty)
                    Text(
                      'No meals planned for today.',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
                    )
                  else
                    ...planned.map((type) {
                      final match = meals.cast<Map<String, dynamic>?>().firstWhere(
                            (m) => m?['type']?.toString() == type,
                            orElse: () => null,
                          );
                      final done = match?['followed'] == true;
                      final label = switch (type) {
                        'breakfast' => 'Breakfast',
                        'lunch' => 'Lunch',
                        'dinner' => 'Dinner',
                        _ => 'Snacks',
                      };
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${done ? '✅' : '❌'} $label',
                          style: TextStyle(
                            color: done ? CoachDashboardTheme.success : CoachDashboardTheme.danger,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _DayMealsBucket {
  final Map<String, _MealForm> mealForms = {
    'breakfast': _MealForm(),
    'lunch': _MealForm(),
    'dinner': _MealForm(),
  };
  final List<_MealForm> snackForms = [];

  void clear() {
    for (final form in mealForms.values) {
      form.name.clear();
      form.description.clear();
      form.reminder.clear();
    }
    for (final form in snackForms) {
      form.dispose();
    }
    snackForms.clear();
  }

  void loadFromMeals(List<DietMeal> meals) {
    clear();
    for (final meal in meals) {
      if (meal.type == 'snacks') {
        snackForms.add(_MealForm()..load(meal));
      } else {
        mealForms[meal.type]?.load(meal);
      }
    }
  }

  List<DietMeal> buildMeals() {
    final meals = mealForms.entries
        .where((e) => e.value.hasContent)
        .map((e) => e.value.toMeal(e.key))
        .toList();
    meals.addAll(snackForms.where((f) => f.hasContent).map((f) => f.toMeal('snacks')));
    return meals;
  }

  void dispose() {
    for (final form in mealForms.values) {
      form.dispose();
    }
    for (final form in snackForms) {
      form.dispose();
    }
    snackForms.clear();
  }
}

class _MealForm {
  final name = TextEditingController();
  final description = TextEditingController();
  final reminder = TextEditingController();

  bool get hasContent => name.text.isNotEmpty || description.text.isNotEmpty;

  void load(DietMeal meal) {
    name.text = meal.name;
    description.text = meal.description;
    reminder.text = meal.reminderTime;
  }

  DietMeal toMeal(String type) => DietMeal(
        type: type,
        name: name.text.trim().isEmpty
            ? (type == 'snacks' ? 'Snack' : DietMeal.empty(type).name)
            : name.text.trim(),
        description: description.text.trim(),
        reminderTime: reminder.text.trim(),
      );

  void dispose() {
    name.dispose();
    description.dispose();
    reminder.dispose();
  }
}

const List<String> _snackOptions = [
  'Greek yogurt with berries',
  'Apple with peanut butter',
  'Handful of almonds',
  'Mixed nuts',
  'Protein bar',
  'Protein shake',
  'Cottage cheese',
  'Hummus with carrot sticks',
  'Banana',
  'Boiled eggs',
  'Rice cakes',
  'Dark chocolate (1 square)',
  'Trail mix',
  'String cheese',
  'Edamame',
  'Oatmeal',
];

class _MealSection extends StatelessWidget {
  final String label;
  final _MealForm form;
  final bool isDark;
  final bool readOnly;

  const _MealSection({
    required this.label,
    required this.form,
    required this.isDark,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: ExpansionTile(
        title: Text(label[0].toUpperCase() + label.substring(1), style: CoachDashboardTheme.sectionTitle(isDark)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                TextField(
                  controller: form.name,
                  readOnly: readOnly,
                  decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Meal Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: form.description,
                  readOnly: readOnly,
                  decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Description'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: form.reminder,
                  readOnly: readOnly,
                  decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Reminder Time (e.g. 08:00)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SnacksListSection extends StatelessWidget {
  final List<_MealForm> snackForms;
  final List<_MealForm> customSnackForms;
  final bool isDark;
  final bool readOnly;
  final bool Function(String name) isPresetSelected;
  final void Function(String name, bool selected) onTogglePreset;
  final void Function({String? presetName}) onAdd;
  final void Function(_MealForm form) onRemove;

  const _SnacksListSection({
    required this.snackForms,
    required this.customSnackForms,
    required this.isDark,
    required this.readOnly,
    required this.isPresetSelected,
    required this.onTogglePreset,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final filledCount = snackForms.where((f) => f.hasContent).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text('Snacks', style: CoachDashboardTheme.sectionTitle(isDark)),
        subtitle: Text(
          filledCount == 0 ? 'Select snacks below' : '$filledCount snack${filledCount == 1 ? '' : 's'} selected',
          style: CoachDashboardTheme.bodyMuted(isDark),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select snacks', style: CoachDashboardTheme.bodyMuted(isDark)),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 240),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _snackOptions.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                    itemBuilder: (context, i) {
                      final option = _snackOptions[i];
                      final selected = isPresetSelected(option);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: readOnly ? null : (v) => onTogglePreset(option, v ?? false),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        activeColor: CoachDashboardTheme.primary,
                        title: Text(option, style: const TextStyle(fontSize: 13)),
                      );
                    },
                  ),
                ),
                if (customSnackForms.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Custom snacks', style: CoachDashboardTheme.bodyMuted(isDark)),
                  const SizedBox(height: 8),
                ],
                ...customSnackForms.asMap().entries.map((entry) {
                  final form = entry.value;
                  final index = entry.key + 1;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Custom snack $index', style: CoachDashboardTheme.sectionTitle(isDark)),
                            const Spacer(),
                            if (!readOnly)
                              IconButton(
                                tooltip: 'Remove snack',
                                onPressed: () => onRemove(form),
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: CoachDashboardTheme.danger.withValues(alpha: 0.85),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: form.name,
                          readOnly: readOnly,
                          decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Snack Name'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: form.description,
                          readOnly: readOnly,
                          decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Notes (optional)'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: form.reminder,
                          readOnly: readOnly,
                          decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Reminder Time (e.g. 15:00)'),
                        ),
                      ],
                    ),
                  );
                }),
                if (!readOnly) ...[
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () => onAdd(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Custom Snack'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
