import 'package:flutter/material.dart';
import 'widgets/coach_home/coach_dashboard_theme.dart';
import '../../models/diet_plan_model.dart';
import '../../models/diet_today_progress_model.dart';
import '../../services/api_service.dart';
import '../../widgets/diet_progress_panel.dart';
import '../../widgets/scrollable_body.dart';

class UserDietPlanScreen extends StatefulWidget {
  const UserDietPlanScreen({super.key});

  @override
  State<UserDietPlanScreen> createState() => UserDietPlanScreenState();
}

class UserDietPlanScreenState extends State<UserDietPlanScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabs;
  bool _loading = true;
  String _error = '';
  DietPlan? _plan;
  DietTodayProgress _today = const DietTodayProgress();
  int _avgAdherence = 0;
  int _weeklyAverage = 0;
  final Map<String, bool> _mealFollowed = {};
  final Map<String, DateTime?> _mealCompletedAt = {};
  List<DietPlan> _history = [];
  bool _historyLoading = false;
  int _browseDay = DietDay.mondayBasedDayOfWeek();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTabChanged);
    _load();
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    if (_tabs.index == 1) {
      _load();
    } else if (_tabs.index == 2) {
      _loadHistory();
    }
  }

  Future<void> refresh() => _load();

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final planResult = await _api.getDietPlan();
      final progress = await _api.getUserDietProgress();
      final planData = planResult != null
          ? Map<String, dynamic>.from(planResult)
          : <String, dynamic>{};
      final progressMap = Map<String, dynamic>.from(progress);

      final planJson = planData['plan'] as Map<String, dynamic>?;
      final todayJson = (planData['today'] as Map<String, dynamic>?) ??
          (progressMap['today'] as Map<String, dynamic>?);
      final adherence = todayJson?['adherence'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _plan = planJson != null ? DietPlan.fromJson(planJson) : null;
          if (_plan != null) {
            _browseDay = _plan!.targetDayOfWeek
                ?? _plan!.todayDayOfWeek
                ?? DietDay.mondayBasedDayOfWeek();
          }
          _today = DietTodayProgress.fromJson(todayJson);
          if (_plan != null && _today.targetCalories == 0) {
            final planned = _plan!.mealsForDay().where((m) => m.hasContent).length;
            _today = DietTodayProgress(
              caloriesConsumed: _today.caloriesConsumed,
              targetCalories: _plan!.dailyCalories,
              waterMl: _today.waterMl,
              targetWaterMl: _today.targetWaterMl,
              mealsCompleted: _today.mealsCompleted,
              mealsPlanned: _today.mealsPlanned > 0
                  ? _today.mealsPlanned
                  : planned,
              workoutsCompleted: _today.workoutsCompleted,
              workoutsPlanned: _today.workoutsPlanned,
              dailyGoalPercent: _today.dailyGoalPercent,
              adherencePercent: _today.adherencePercent,
              followedPlan: _today.followedPlan,
              hasActivity: _today.hasActivity,
            );
          }
          _avgAdherence = (progressMap['avgAdherence'] as num?)?.toInt() ?? 0;
          _weeklyAverage = (progressMap['weeklyAveragePercent'] as num?)?.toInt()
              ?? (todayJson?['weeklyAveragePercent'] as num?)?.toInt()
              ?? 0;
          _mealFollowed.clear();
          _mealCompletedAt.clear();
          final mealAdherence = adherence?['mealAdherence'] as List<dynamic>? ??
              (todayJson?['mealAdherence'] as List<dynamic>? ?? []);
          for (final entry in mealAdherence) {
            if (entry is Map) {
              final type = entry['type']?.toString();
              if (type != null) {
                _mealFollowed[type] = entry['followed'] == true;
                _mealCompletedAt[type] = DateTime.tryParse(entry['completedAt']?.toString() ?? '');
              }
            }
          }
          _error = '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiService.friendlyError(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    try {
      final plans = await _api.getUserDietPlanHistory();
      if (!mounted) return;
      setState(() {
        _history = plans.map((p) => DietPlan.fromJson(Map<String, dynamic>.from(p as Map))).toList();
        _historyLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<void> _toggleMeal(String type, bool value) async {
    final previous = _mealFollowed[type] ?? false;
    setState(() => _mealFollowed[type] = value);
    try {
      await _api.logDietAdherence({
        'mealType': type,
        'followed': value,
        'caloriesConsumed': _today.caloriesConsumed,
      });
      await _load();
      if (mounted && value) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_labelForType(type)} marked as completed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _mealFollowed[type] = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  int get _completedMealCount => _plannedMealTypes().where((t) => _mealFollowed[t] == true).length;

  int get _plannedMealCount => _plannedMealTypes().length;

  int get _dailyMealPercent =>
      _plannedMealCount > 0 ? ((_completedMealCount / _plannedMealCount) * 100).round() : 0;

  Future<void> _logMeal() async {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Meal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Meal name')),
            TextField(controller: calCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Calories')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _api.logMeal(
        mealName: nameCtrl.text.trim().isEmpty ? 'Meal' : nameCtrl.text.trim(),
        calories: double.tryParse(calCtrl.text) ?? 0,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _logWater() async {
    final ctrl = TextEditingController(text: '250');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Water'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (ml)', suffixText: 'ml'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.logWater(double.tryParse(ctrl.text) ?? 0);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      appBar: CoachDashboardTheme.coachAppBar(
        context: context,
        title: _plan?.title ?? 'My Diet Plan',
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () {
            if (_tabs.index == 2) {
              _loadHistory();
            } else {
              _load();
            }
          }),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: CoachDashboardTheme.primary,
          indicatorColor: CoachDashboardTheme.primary,
          unselectedLabelColor: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
          tabs: const [
            Tab(text: 'Plan'),
            Tab(text: 'Progress'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _loading && _tabs.index != 2
          ? const ScrollableCenter(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _error.isNotEmpty
                    ? ScrollableCenter(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.restaurant_menu_rounded, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(_error, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            TextButton(onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _plan == null
                        ? const ScrollableCenter(
                            child: Text('No active diet plan assigned yet.', textAlign: TextAlign.center),
                          )
                        : _buildPlanTab(isDark),
                _plan == null
                    ? const ScrollableCenter(
                        child: Text('No active diet plan to track yet.', textAlign: TextAlign.center),
                      )
                    : DietProgressPanel(
                        today: _today,
                        avgAdherence: _avgAdherence,
                        weeklyAveragePercent: _weeklyAverage,
                        mealTypes: _plannedMealTypes(),
                        mealFollowed: _mealFollowed,
                        isDark: isDark,
                        onRefresh: _load,
                      ),
                _buildHistoryTab(isDark),
              ],
            ),
      floatingActionButton: _plan == null || _tabs.index != 0
          ? null
          : FloatingActionButton.extended(
              onPressed: _logMeal,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Log Meal'),
              backgroundColor: const Color(0xFF10B981),
            ),
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    if (_historyLoading) {
      return const ScrollableCenter(child: CircularProgressIndicator());
    }
    if (_history.isEmpty) {
      return const ScrollableCenter(
        child: Text(
          'No previous diet plans yet.\nWhen a new plan is assigned, the old one appears here.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      physics: dashboardScrollPhysics,
      padding: const EdgeInsets.all(18),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final plan = _history[i];
        final date = plan.updatedAt ?? plan.createdAt;
        final dateLabel = date == null
            ? ''
            : '${date.day}/${date.month}/${date.year}';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: CoachDashboardTheme.cardDecoration(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(plan.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: CoachDashboardTheme.textSecondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      plan.isGroupPlan ? 'Group' : 'Personal',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${plan.dailyCalories} kcal/day · ${plan.goal.replaceAll('_', ' ')}'
                '${dateLabel.isNotEmpty ? ' · Ended $dateLabel' : ''}',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600),
              ),
              if (plan.meals.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  plan.meals.map((m) => m.name.isNotEmpty ? m.name : m.type).where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlanTab(bool isDark) {
    return ListView(
      physics: dashboardScrollPhysics,
      padding: const EdgeInsets.all(18),
      children: [
        _summaryCard(isDark),
        if (_plan!.isWeekly || _plan!.targetDayOfWeek != null) ...[
          const SizedBox(height: 12),
          Text(
            _plan!.isWeekly ? 'Meals by day' : 'Plan day',
            style: CoachDashboardTheme.sectionTitle(isDark),
          ),
          const SizedBox(height: 4),
          Text(
            _plan!.isWeekly
                ? 'Browse each day of your weekly diet plan. Check-ins always use today’s meals.'
                : 'This plan is for ${_plan!.targetDayName ?? DietDay.dayNames[_plan!.targetDayOfWeek!.clamp(0, 6)]}.',
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
                  Builder(
                    builder: (_) {
                      final isTarget = !_plan!.isWeekly && _plan!.targetDayOfWeek == i;
                      final hasMeals = _plan!.mealsForDay(i).where((m) => m.hasContent).isNotEmpty;
                      final isToday = i == (_plan!.todayDayOfWeek ?? DietDay.mondayBasedDayOfWeek());
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: CoachDashboardTheme.primary,
                        value: _browseDay == i,
                        title: Text(
                          DietDay.dayNames[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _browseDay == i ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (isToday) 'Today',
                            if (isTarget) 'Assigned day',
                            if (hasMeals) '${_plan!.mealsForDay(i).where((m) => m.hasContent).length} meal(s)',
                            if (!hasMeals && !isTarget) 'No meals',
                          ].where((s) => s.isNotEmpty).join(' · '),
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey),
                        ),
                        onChanged: (v) {
                          if (v == true) setState(() => _browseDay = i);
                        },
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DietDay.dayNames[_browseDay],
            style: const TextStyle(fontWeight: FontWeight.w700, color: CoachDashboardTheme.primary),
          ),
        ],
        const SizedBox(height: 12),
        _mealProgressCard(isDark),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _logWater,
                icon: const Icon(Icons.water_drop_outlined),
                label: const Text('Log Water'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Today’s Meal Check-in', style: CoachDashboardTheme.sectionTitle(isDark)),
        const SizedBox(height: 4),
        Text(
          _plan!.isWeekly
              ? 'Check each meal for ${DietDay.dayNames[_plan!.todayDayOfWeek ?? DietDay.mondayBasedDayOfWeek()]} after you complete it.'
              : 'Check each meal only after you complete it.',
          style: CoachDashboardTheme.bodyMuted(isDark),
        ),
        const SizedBox(height: 8),
        ..._orderedPlannedMealTypes().map((type) => _mealCheckInTile(type, isDark)),
        if (_plan!.notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(_plan!.notes))),
        ],
        const SizedBox(height: 16),
        Text(
          _plan!.isWeekly ? 'Meal Plan · ${DietDay.dayNames[_browseDay]}' : 'Meal Plan',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _mealSection('breakfast', isDark),
        _mealSection('lunch', isDark),
        _mealSection('dinner', isDark),
        _snacksSection(isDark),
        const SizedBox(height: 80),
      ],
    );
  }

  List<DietMeal> get _todayMeals =>
      _plan?.mealsForDay(_plan!.todayDayOfWeek ?? DietDay.mondayBasedDayOfWeek()) ?? const [];

  List<DietMeal> get _browseMeals =>
      _plan?.mealsForDay(
        (_plan!.isWeekly || _plan!.targetDayOfWeek != null) ? _browseDay : null,
      ) ??
      const [];

  List<String> _plannedMealTypes() {
    final types = <String>[];
    for (final meal in _todayMeals) {
      if (meal.hasContent && !types.contains(meal.type)) {
        types.add(meal.type);
      }
    }
    return types;
  }

  List<String> _orderedPlannedMealTypes() {
    const order = ['breakfast', 'lunch', 'dinner', 'snacks'];
    final planned = _plannedMealTypes();
    return order.where(planned.contains).toList();
  }

  Widget _mealProgressCard(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_completedMealCount/$_plannedMealCount Meals Completed ($_dailyMealPercent%)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _plannedMealCount > 0 ? (_completedMealCount / _plannedMealCount).clamp(0.0, 1.0) : 0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              color: const Color(0xFF10B981),
            ),
            const SizedBox(height: 8),
            Text('Weekly average: $_weeklyAverage%', style: CoachDashboardTheme.bodyMuted(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _mealCheckInTile(String type, bool isDark) {
    final completed = _mealFollowed[type] ?? false;
    final completedAt = _mealCompletedAt[type];
    final timeLabel = completedAt != null
        ? 'Completed at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(completedAt.toLocal()))}'
        : 'Not completed yet';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: completed,
        onChanged: (v) => _toggleMeal(type, v ?? false),
        title: Text(_labelForType(type), style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          timeLabel,
          style: TextStyle(
            fontSize: 12,
            color: completed ? const Color(0xFF10B981) : (isDark ? Colors.white54 : Colors.black54),
          ),
        ),
        secondary: Text(completed ? '✅' : '⏳', style: const TextStyle(fontSize: 20)),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _summaryCard(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_plan!.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              _plan!.planTypeLabel,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CoachDashboardTheme.primary),
            ),
            if (_plan!.isGroupPlan) ...[
              const SizedBox(height: 6),
              Text(
                'Group plan · ${_plan!.fitnessClass?['title'] ?? 'Class'}',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : CoachDashboardTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 8),
            Text('${_today.caloriesConsumed} / ${_today.targetCalories} kcal today'),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _today.caloriesProgress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              color: const Color(0xFF10B981),
            ),
          ],
        ),
      ),
    );
  }

  List<DietMeal> _mealsOfType(String type) => _browseMeals.where((m) => m.type == type).toList();

  DietMeal? _mealOfType(String type) {
    for (final m in _browseMeals) {
      if (m.type == type) return m;
    }
    return null;
  }

  String _labelForType(String type) {
    switch (type) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      default:
        return 'Snacks';
    }
  }

  Widget _snacksSection(bool isDark) {
    final snacks = _mealsOfType('snacks');
    final hasContent = snacks.any((meal) => meal.name.trim().isNotEmpty || meal.description.trim().isNotEmpty);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0x2610B981),
                  child: Icon(Icons.cookie_rounded, color: Color(0xFF10B981), size: 20),
                ),
                SizedBox(width: 10),
                Expanded(child: Text('Snacks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 8),
            if (!hasContent)
              Text('Nothing planned', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: isDark ? Colors.white38 : Colors.black38))
            else
              ...snacks.map((meal) => _snackItem(meal, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _snackItem(DietMeal meal, bool isDark) {
    final name = meal.name.trim();
    final desc = meal.description.trim();
    if (name.isEmpty && desc.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Snack' : name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (desc.isNotEmpty) Text(desc, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealSection(String type, bool isDark) {
    final meal = _mealOfType(type);
    final label = _labelForType(type);
    final mealName = meal?.name.trim() ?? '';
    final hasName = mealName.isNotEmpty && mealName.toLowerCase() != label.toLowerCase();
    final desc = meal?.description.trim() ?? '';
    final hasContent = hasName || desc.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                  child: Icon(_iconForType(type), color: const Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 8),
            if (!hasContent)
              Text('Nothing planned', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: isDark ? Colors.white38 : Colors.black38))
            else ...[
              if (hasName) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(mealName, style: const TextStyle(fontWeight: FontWeight.w600))),
              if (desc.isNotEmpty) Text(desc, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'breakfast':
        return Icons.free_breakfast_rounded;
      case 'lunch':
        return Icons.lunch_dining_rounded;
      case 'dinner':
        return Icons.dinner_dining_rounded;
      default:
        return Icons.cookie_rounded;
    }
  }
}
