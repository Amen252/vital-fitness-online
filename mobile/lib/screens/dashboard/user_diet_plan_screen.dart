import 'package:flutter/material.dart';
import 'widgets/coach_home/coach_dashboard_theme.dart';
import '../../models/diet_plan_model.dart';
import '../../models/diet_today_progress_model.dart';
import '../../services/api_service.dart';
import '../../utils/date_utils.dart';
import '../../widgets/diet_progress_panel.dart';
import '../../widgets/scrollable_body.dart';

class UserDietPlanScreen extends StatefulWidget {
  final VoidCallback? onDietDataChanged;

  const UserDietPlanScreen({super.key, this.onDietDataChanged});

  @override
  State<UserDietPlanScreen> createState() => UserDietPlanScreenState();
}

class UserDietPlanScreenState extends State<UserDietPlanScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabs;
  bool _loading = true;
  bool _savingMeal = false;
  String _error = '';
  DietPlan? _plan;
  DietTodayProgress _today = const DietTodayProgress();
  int _avgAdherence = 0;
  int _weeklyAverage = 0;
  final Map<String, bool> _mealFollowed = {};
  final Map<String, DateTime?> _mealCompletedAt = {};
  final Map<int, bool> _dayCompleted = {};
  final Map<int, DateTime?> _dayCompletedAt = {};
  final Map<int, DateTime?> _dayDates = {};
  final Map<int, bool> _dayCanCheckIn = {};
  final Map<int, bool> _dayIsFuture = {};
  final Map<int, List<Map<String, dynamic>>> _dayMealAdherence = {};
  List<DietPlan> _history = [];
  List<Map<String, dynamic>> _adherenceHistory = [];
  bool _historyLoading = false;
  int _browseDay = DietDay.mondayBasedDayOfWeek();
  int _completedDays = 0;
  int _daysPlanned = 7;
  final Set<String> _expandedMealCards = <String>{};
  bool _coachNotesExpanded = false;
  bool _weeklyProgressExpanded = true;

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
      _load(silent: true);
    } else if (_tabs.index == 2) {
      _loadHistory();
    }
  }

  Future<void> refresh() => _load(silent: false);

  /// Background refresh used when returning to this tab — keeps content visible.
  Future<void> refreshQuietly() => _load(silent: true);

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    // Only show full-screen loader on the first load (no plan/progress yet).
    final hasContent = _plan != null || _today.mealsPlanned > 0 || _error.isNotEmpty;
    if (!silent && !hasContent && mounted) setState(() => _loading = true);
    final browseDayBeforeLoad = _browseDay;
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
            if (_plan!.isWeekly) {
              _browseDay = silent
                  ? browseDayBeforeLoad.clamp(0, 6)
                  : (_plan!.todayDayOfWeek ?? DietDay.mondayBasedDayOfWeek());
            } else {
              _browseDay = silent
                  ? browseDayBeforeLoad.clamp(0, 6)
                  : (_plan!.targetDayOfWeek ??
                      _plan!.todayDayOfWeek ??
                      DietDay.mondayBasedDayOfWeek());
            }
          }
          _today = DietTodayProgress.fromJson(todayJson);
          if (_plan != null && _today.targetCalories == 0) {
            final planned =
                _plan!.mealsForDay().where((m) => m.hasContent).length;
            _today = _today.copyWith(
              targetCalories: _plan!.dailyCalories,
              mealsPlanned:
                  _today.mealsPlanned > 0 ? _today.mealsPlanned : planned,
            );
          }
          _avgAdherence = (progressMap['avgAdherence'] as num?)?.toInt() ?? 0;
          _weeklyAverage =
              (progressMap['weeklyAveragePercent'] as num?)?.toInt() ??
                  (todayJson?['weeklyAveragePercent'] as num?)?.toInt() ??
                  0;
          _mealFollowed.clear();
          _mealCompletedAt.clear();
          _dayCompleted.clear();
          _dayCompletedAt.clear();
          _dayDates.clear();
          _dayCanCheckIn.clear();
          _dayIsFuture.clear();
          _dayMealAdherence.clear();
          final mealAdherence = adherence?['mealAdherence'] as List<dynamic>? ??
              (todayJson?['mealAdherence'] as List<dynamic>? ?? []);
          for (final entry in mealAdherence) {
            if (entry is Map) {
              final type = entry['type']?.toString();
              if (type != null) {
                _mealFollowed[type] = entry['followed'] == true;
                _mealCompletedAt[type] =
                    DateTime.tryParse(entry['completedAt']?.toString() ?? '');
              }
            }
          }
          for (final entry in _today.mealAdherence) {
            final type = entry['type']?.toString();
            if (type == null) continue;
            _mealFollowed.putIfAbsent(type, () => entry['followed'] == true);
            _mealCompletedAt.putIfAbsent(
              type,
              () => DateTime.tryParse(entry['completedAt']?.toString() ?? ''),
            );
          }
          final weekCompletion = todayJson?['weekCompletion'] as Map<String, dynamic>? ??
              (progressMap['weekCompletion'] as Map<String, dynamic>?);
          if (weekCompletion != null) {
            _completedDays = (weekCompletion['completedDays'] as num?)?.toInt() ?? 0;
            _daysPlanned = (weekCompletion['daysPlanned'] as num?)?.toInt() ?? 7;
            final days = weekCompletion['days'] as List<dynamic>? ?? [];
            for (final day in days) {
              if (day is! Map) continue;
              final dow = (day['dayOfWeek'] as num?)?.toInt();
              if (dow == null) continue;
              _dayCompleted[dow] = day['completed'] == true;
              _dayCompletedAt[dow] =
                  DateTime.tryParse(day['completedAt']?.toString() ?? '');
              _dayDates[dow] = parseApiDateOnly(
                    day['dateOnly']?.toString() ?? day['date']?.toString(),
                  ) ??
                  _plan?.dateForDayOfWeek(dow);
              final canCheck = day['canCheckIn'] != false && day['isFuture'] != true;
              _dayCanCheckIn[dow] = canCheck;
              _dayIsFuture[dow] = day['isFuture'] == true || day['isUpcoming'] == true;
              _dayMealAdherence[dow] = (day['mealAdherence'] as List<dynamic>? ?? [])
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
            }
            _hydrateMealsForBrowseDay();
          } else {
            _completedDays = 0;
            _daysPlanned = 7;
            _seedDayDatesFromPlan();
          }
          _error = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiService.friendlyError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    try {
      final results = await Future.wait([
        _api.getUserDietPlanHistory(),
        _api.getUserDietProgress(days: 30),
      ]);
      final plans = results[0] as List<dynamic>;
      final progress = Map<String, dynamic>.from(results[1] as Map);
      if (!mounted) return;
      setState(() {
        _history = plans
            .map((p) => DietPlan.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList();
        _adherenceHistory = (progress['adherenceHistory'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  void _seedDayDatesFromPlan() {
    if (_plan == null || !_plan!.isWeekly) return;
    final today = dateOnly(DateTime.now());
    for (var i = 0; i < 7; i++) {
      final d = _plan!.dateForDayOfWeek(i);
      _dayDates[i] = d;
      if (d == null) {
        _dayCanCheckIn[i] = i <= DietDay.mondayBasedDayOfWeek();
        _dayIsFuture[i] = i > DietDay.mondayBasedDayOfWeek();
      } else {
        final day = dateOnly(d);
        _dayCanCheckIn[i] = !day.isAfter(today);
        _dayIsFuture[i] = day.isAfter(today);
      }
    }
  }

  DateTime? _dateForDay(int dayOfWeek) =>
      _dayDates[dayOfWeek] ?? _plan?.dateForDayOfWeek(dayOfWeek);

  String _dayAndDateLabel(int dayOfWeek) {
    final d = _dateForDay(dayOfWeek);
    if (d == null) return DietDay.dayNames[dayOfWeek.clamp(0, 6)];
    return DietDay(
      dayOfWeek: dayOfWeek,
      date: d,
    ).dayAndDateLabel;
  }

  Map<String, dynamic> _adherenceMetaForDay(int dayOfWeek) {
    final meta = <String, dynamic>{
      'dayOfWeek': dayOfWeek,
      'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
    };
    final d = _dateForDay(dayOfWeek);
    if (d != null) meta['date'] = formatDateOnly(d);
    return meta;
  }

  Future<void> _toggleDay(int dayOfWeek, bool value) async {
    if (_plan == null || !_plan!.isWeekly || _savingMeal) return;
    if (!(_dayCanCheckIn[dayOfWeek] ?? !_isFutureDay(dayOfWeek))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This day is locked until its date arrives.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    final previous = _dayCompleted[dayOfWeek] ?? false;
    final previousAt = _dayCompletedAt[dayOfWeek];
    final previousCompletedDays = _completedDays;

    setState(() {
      _savingMeal = true;
      _dayCompleted[dayOfWeek] = value;
      _dayCompletedAt[dayOfWeek] = value ? DateTime.now() : null;
      _completedDays = _dayCompleted.values.where((v) => v).length;
    });

    try {
      final result = await _api.logDietAdherence({
        ..._adherenceMetaForDay(dayOfWeek),
        'dayCompleted': value,
      });
      if (!mounted) return;
      final week = result['weekCompletion'] as Map<String, dynamic>?;
      if (week != null) {
        setState(() {
          _completedDays = (week['completedDays'] as num?)?.toInt() ?? _completedDays;
          _daysPlanned = (week['daysPlanned'] as num?)?.toInt() ?? 7;
          _weeklyAverage =
              (week['weeklyProgressPercent'] as num?)?.toInt() ?? _weeklyAverage;
          for (final day in (week['days'] as List<dynamic>? ?? [])) {
            if (day is! Map) continue;
            final dow = (day['dayOfWeek'] as num?)?.toInt();
            if (dow == null) continue;
            _dayCompleted[dow] = day['completed'] == true;
            _dayCompletedAt[dow] =
                DateTime.tryParse(day['completedAt']?.toString() ?? '');
            _dayMealAdherence[dow] = (day['mealAdherence'] as List<dynamic>? ?? [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
          _hydrateMealsForBrowseDay();
        });
      }
      await _load(silent: true);
      widget.onDietDataChanged?.call();
      if (mounted && value) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_dayAndDateLabel(dayOfWeek)} marked complete.'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dayCompleted[dayOfWeek] = previous;
          _dayCompletedAt[dayOfWeek] = previousAt;
          _completedDays = previousCompletedDays;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.friendlyError(e)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingMeal = false);
    }
  }

  Future<void> _toggleMeal(String type, bool value) async {
    if (!_canCheckInForBrowseDay || _savingMeal) return;

    final previous = _mealFollowed[type] ?? false;
    final previousCompletedAt = _mealCompletedAt[type];
    final previousToday = _today;

    setState(() {
      _savingMeal = true;
      _mealFollowed[type] = value;
      _mealCompletedAt[type] = value ? DateTime.now() : null;
      _today = _todayWithMealProgress();
    });

    try {
      final payload = <String, dynamic>{
        'mealType': type,
        'followed': value,
        'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      };
      if (_plan?.isWeekly == true) {
        payload.addAll(_adherenceMetaForDay(_browseDay));
      }
      final result = await _api.logDietAdherence(payload);

      if (!mounted) return;

      final summary = result['mealSummary'] as Map<String, dynamic>?;
      final meals = summary?['meals'] as List<dynamic>?;
      final todayPayload = result['today'] as Map<String, dynamic>?;
      final nutrition = result['nutrition'] as Map<String, dynamic>?;

      setState(() {
        if (meals != null) {
          for (final entry in meals) {
            if (entry is! Map) continue;
            final t = entry['type']?.toString();
            if (t == null) continue;
            _mealFollowed[t] =
                entry['completed'] == true || entry['followed'] == true;
            _mealCompletedAt[t] =
                DateTime.tryParse(entry['completedAt']?.toString() ?? '');
          }
        }
        final completed =
            (summary?['completedMeals'] as num?)?.toInt() ?? _completedMealCount;
        final planned =
            (summary?['mealsPlanned'] as num?)?.toInt() ?? _plannedMealCount;
        final pct = (summary?['dailyProgressPercent'] as num?)?.toInt() ??
            (planned > 0 ? ((completed / planned) * 100).round() : 0);
        _weeklyAverage =
            (result['weeklyAveragePercent'] as num?)?.toInt() ?? _weeklyAverage;
        final week = result['weekCompletion'] as Map<String, dynamic>?;
        if (week != null) {
          _completedDays =
              (week['completedDays'] as num?)?.toInt() ?? _completedDays;
          _daysPlanned = (week['daysPlanned'] as num?)?.toInt() ?? 7;
          for (final day in (week['days'] as List<dynamic>? ?? [])) {
            if (day is! Map) continue;
            final dow = (day['dayOfWeek'] as num?)?.toInt();
            if (dow == null) continue;
            _dayCompleted[dow] = day['completed'] == true;
            _dayCompletedAt[dow] =
                DateTime.tryParse(day['completedAt']?.toString() ?? '');
            _dayMealAdherence[dow] = (day['mealAdherence'] as List<dynamic>? ?? [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
          _hydrateMealsForBrowseDay();
        }

        if (todayPayload != null) {
          _today = DietTodayProgress.fromJson(todayPayload).copyWith(
            weeklyAveragePercent: _weeklyAverage > 0
                ? _weeklyAverage
                : (todayPayload['weeklyAveragePercent'] as num?)?.toInt(),
          );
        } else {
          _today = _todayWithMealProgress(
            caloriesConsumed: (result['caloriesConsumed'] as num?)?.toInt(),
            mealsCompleted: completed,
            mealsPlanned: planned,
            dailyGoalPercent: pct,
            adherencePercent: pct,
            followedPlan: summary?['allCompleted'] == true,
            proteinConsumed: (nutrition?['protein'] as num?)?.toInt(),
            carbsConsumed: (nutrition?['carbs'] as num?)?.toInt(),
            fatsConsumed: (nutrition?['fats'] as num?)?.toInt(),
          );
        }
      });

      // Full silent reload keeps water/workouts/daily goal in sync with DB.
      await _load(silent: true);
      if (_tabs.index == 2) {
        await _loadHistory();
      }
      widget.onDietDataChanged?.call();

      if (mounted && value) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_labelForType(type)} marked as completed.'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mealFollowed[type] = previous;
          _mealCompletedAt[type] = previousCompletedAt;
          _today = previousToday;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.friendlyError(e)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingMeal = false);
    }
  }

  int get _completedMealCount =>
      _plannedMealTypes().where((t) => _mealFollowed[t] == true).length;

  int get _plannedMealCount => _plannedMealTypes().length;

  int get _dailyMealPercent => _plannedMealCount > 0
      ? ((_completedMealCount / _plannedMealCount) * 100).round()
      : 0;

  DietTodayProgress get _mealProgressSnapshot {
    final planned = _plannedMealCount;
    final completed = _completedMealCount;
    final pct = _dailyMealPercent;
    return _today.copyWith(
      caloriesConsumed: _consumedCaloriesFromPlan,
      mealsCompleted: completed,
      mealsPlanned: planned,
      dailyGoalPercent: pct,
      adherencePercent: pct,
      followedPlan: planned > 0 && completed == planned,
      hasActivity: completed > 0 || _today.hasActivity,
      proteinConsumed: _consumedProteinFromPlan,
      carbsConsumed: _consumedCarbsFromPlan,
      fatsConsumed: _consumedFatsFromPlan,
      weeklyAveragePercent: _weeklyAverage,
    );
  }

  int get _todayDow =>
      _plan?.todayDayOfWeek ?? DietDay.mondayBasedDayOfWeek();

  bool _isFutureDay(int dayOfWeek) {
    if (_dayIsFuture[dayOfWeek] == true) return true;
    final d = _dateForDay(dayOfWeek);
    if (d == null) return false;
    return dateOnly(d).isAfter(dateOnly(DateTime.now()));
  }

  bool get _canCheckInToday {
    if (_plan == null) return false;
    if (_plan!.isWeekly) {
      // Always use the device's local calendar day to avoid timezone unlock races.
      return !_isFutureDay(_todayDow);
    }
    if (_plan!.targetDayOfWeek == null) return true;
    return _plan!.targetDayOfWeek == _todayDow;
  }

  /// Meal check-ins apply to the selected weekly day (or today for single-day).
  /// Future calendar days stay locked until their date arrives.
  bool get _canCheckInForBrowseDay {
    if (_plan == null) return false;
    if (_plan!.isWeekly) {
      return !_isFutureDay(_browseDay);
    }
    return _canCheckInToday;
  }

  void _hydrateMealsForBrowseDay() {
    _mealFollowed.clear();
    _mealCompletedAt.clear();
    final entries = _dayMealAdherence[_browseDay];
    if (entries != null && entries.isNotEmpty) {
      for (final entry in entries) {
        final type = entry['type']?.toString();
        if (type == null) continue;
        _mealFollowed[type] = entry['followed'] == true;
        _mealCompletedAt[type] =
            DateTime.tryParse(entry['completedAt']?.toString() ?? '');
      }
      return;
    }
    if (_browseDay == _todayDow) {
      for (final entry in _today.mealAdherence) {
        final type = entry['type']?.toString();
        if (type == null) continue;
        _mealFollowed[type] = entry['followed'] == true;
        _mealCompletedAt[type] =
            DateTime.tryParse(entry['completedAt']?.toString() ?? '');
      }
    }
  }

  void _selectBrowseDay(int day) {
    setState(() {
      _browseDay = day;
      _hydrateMealsForBrowseDay();
    });
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
          decoration: const InputDecoration(
            labelText: 'Amount (ml)',
            suffixText: 'ml',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.logWater(double.tryParse(ctrl.text) ?? 0);
      await _load(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.friendlyError(e)),
            backgroundColor: Colors.redAccent,
          ),
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
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh latest plan',
            onPressed: () {
              if (_tabs.index == 2) {
                _loadHistory();
              } else {
                _load();
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: CoachDashboardTheme.primary,
          indicatorColor: CoachDashboardTheme.primary,
          unselectedLabelColor:
              isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
          tabs: const [
            Tab(text: 'Plan'),
            Tab(text: 'Progress'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _loading && _plan == null && _error.isEmpty && _tabs.index != 2
          ? const ScrollableCenter(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _error.isNotEmpty
                    ? ScrollableCenter(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.restaurant_menu_rounded,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(_error, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _plan == null
                        ? const ScrollableCenter(
                            child: Text(
                              'No active diet plan assigned yet.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _load(silent: true),
                            child: _buildPlanTab(isDark),
                          ),
                _plan == null
                    ? const ScrollableCenter(
                        child: Text(
                          'No active diet plan to track yet.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : DietProgressPanel(
                        today: _mealProgressSnapshot,
                        avgAdherence: _avgAdherence,
                        weeklyAveragePercent: _weeklyAverage,
                        mealTypes: _orderedPlannedMealTypes(),
                        mealFollowed: _mealFollowed,
                        isDark: isDark,
                        onRefresh: () => _load(silent: true),
                        progressTitle: _plan!.isWeekly
                            ? 'Meal progress · ${_dayAndDateLabel(_browseDay)}'
                            : 'Meal progress · today',
                      ),
                _buildHistoryTab(isDark),
              ],
            ),
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    if (_historyLoading) {
      return const ScrollableCenter(child: CircularProgressIndicator());
    }
    return ListView(
      physics: dashboardScrollPhysics,
      padding: const EdgeInsets.all(18),
      children: [
        Text('Previous diet plans', style: CoachDashboardTheme.sectionTitle(isDark)),
        const SizedBox(height: 4),
        Text(
          'Active plans stay on the Plan tab. Completed/archived plans appear here and are never deleted.',
          style: CoachDashboardTheme.bodyMuted(isDark),
        ),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No previous diet plans yet.\nWhen a new plan is assigned, the old one appears here.',
              textAlign: TextAlign.center,
            ),
          )
        else
          ..._history.map((plan) {
            final date = plan.updatedAt ?? plan.createdAt;
            final dateLabel =
                date == null ? '' : '${date.day}/${date.month}/${date.year}';
            final mealPreview = _historyMealPreview(plan);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: CoachDashboardTheme.cardDecoration(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plan.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        _planTypeChip(plan, isDark),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${plan.statusLabel} · ${plan.dailyCalories} kcal/day · ${plan.goalLabel}'
                      '${dateLabel.isNotEmpty ? ' · $dateLabel' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                    if (mealPreview.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        mealPreview,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 20),
        Text('Recent meal completion', style: CoachDashboardTheme.sectionTitle(isDark)),
        const SizedBox(height: 4),
        Text(
          'Daily check-in history from your meal tracking.',
          style: CoachDashboardTheme.bodyMuted(isDark),
        ),
        const SizedBox(height: 12),
        if (_adherenceHistory.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No meal check-ins yet.',
              style: CoachDashboardTheme.bodyMuted(isDark),
            ),
          )
        else
          ..._adherenceHistory.map((entry) => _adherenceHistoryTile(entry, isDark)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _adherenceHistoryTile(Map<String, dynamic> entry, bool isDark) {
    final date = DateTime.tryParse(entry['date']?.toString() ?? '');
    final dateLabel = date == null
        ? 'Day'
        : '${date.day}/${date.month}/${date.year}';
    final percent = (entry['adherencePercent'] as num?)?.toInt() ?? 0;
    final meals = (entry['mealAdherence'] as List<dynamic>? ?? []);
    final completed = meals.where((m) => m is Map && m['followed'] == true).length;
    final planned = meals.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  planned > 0
                      ? '$completed of $planned meals completed'
                      : (entry['followedPlan'] == true ? 'Plan followed' : 'Logged'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$percent%',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: percent >= 100
                  ? const Color(0xFF10B981)
                  : CoachDashboardTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  String _historyMealPreview(DietPlan plan) {
    if (plan.isWeekly && plan.days.isNotEmpty) {
      final parts = <String>[];
      for (final day in plan.days) {
        final count = day.meals.where((m) => m.hasContent).length;
        if (count > 0) parts.add('${day.dayName}: $count');
      }
      return parts.isEmpty ? '' : 'Weekly · ${parts.join(' · ')}';
    }
    final names = plan.meals
        .where((m) => m.hasContent)
        .map((m) => m.name.isNotEmpty ? m.name : m.type)
        .where((s) => s.isNotEmpty);
    return names.join(' · ');
  }

  Widget _planTypeChip(DietPlan plan, bool isDark) {
    final weekly = plan.isWeekly;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (weekly ? CoachDashboardTheme.primary : const Color(0xFF10B981))
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        weekly ? 'Weekly' : 'Single-Day',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: weekly ? CoachDashboardTheme.primary : const Color(0xFF059669),
        ),
      ),
    );
  }

  Widget _buildPlanTab(bool isDark) {
    final dayName = _plan!.isWeekly
        ? _dayAndDateLabel(_browseDay)
        : DietDay.dayNames[_browseDay.clamp(0, 6)];
    final meals = _orderedPlannedMealTypes();

    return ListView(
      physics: dashboardScrollPhysics,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        _planHeaderCard(isDark),
        const SizedBox(height: 14),
        Text('Daily progress', style: CoachDashboardTheme.sectionTitle(isDark)),
        const SizedBox(height: 8),
        _dailyProgressCard(isDark),
        const SizedBox(height: 16),
        if (_plan!.isWeekly) ...[
          Text('Week · choose a day', style: CoachDashboardTheme.sectionTitle(isDark)),
          const SizedBox(height: 8),
          _daySelector(isDark),
          const SizedBox(height: 16),
        ] else ...[
          _singleDayBanner(isDark),
          const SizedBox(height: 16),
        ],
        Text(
          _plan!.isWeekly ? 'Meals · $dayName' : 'Today\'s meals',
          style: CoachDashboardTheme.sectionTitle(isDark),
        ),
        const SizedBox(height: 4),
        Text(
          _canCheckInForBrowseDay
              ? 'Tap the checkmark to mark a meal complete. Expand a card for details.'
              : 'Check-in opens on the plan day.',
          style: CoachDashboardTheme.bodyMuted(isDark),
        ),
        const SizedBox(height: 10),
        if (meals.isEmpty)
          _emptyStateCard(
            isDark,
            icon: Icons.no_meals_rounded,
            message: 'No meals planned for this day.',
          )
        else
          ...meals.map((type) => _mealExpandableCard(type, isDark)),
        if (_plan!.isWeekly) ...[
          const SizedBox(height: 8),
          _markDayCompleteTile(isDark),
        ],
        if (_dayOrPlanNotes().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Coach notes', style: CoachDashboardTheme.sectionTitle(isDark)),
          const SizedBox(height: 8),
          _coachNotesCard(isDark),
        ],
        if (_plan!.isWeekly) ...[
          const SizedBox(height: 16),
          Text('Weekly progress', style: CoachDashboardTheme.sectionTitle(isDark)),
          const SizedBox(height: 8),
          _weeklyProgressCard(isDark),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _logWater,
          icon: const Icon(Icons.water_drop_outlined),
          label: const Text('Log water'),
        ),
      ],
    );
  }

  String _dayOrPlanNotes() {
    if (_plan == null) return '';
    if (_plan!.isWeekly) {
      for (final d in _plan!.days) {
        if (d.dayOfWeek == _browseDay && d.notes.trim().isNotEmpty) {
          return d.notes.trim();
        }
      }
    }
    return _plan!.notes.trim();
  }

  Widget _planHeaderCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _plan!.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              _planTypeChip(_plan!, isDark),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_plan!.goalLabel} · ${_plan!.dailyCalories} kcal/day',
            style: CoachDashboardTheme.bodyMuted(isDark),
          ),
          if (_plan!.isGroupPlan) ...[
            const SizedBox(height: 4),
            Text(
              'Group plan · ${_plan!.displayAssigneeName}',
              style: CoachDashboardTheme.bodyMuted(isDark).copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dailyProgressCard(bool isDark) {
    final planned = _plannedMealCount;
    final completed = _completedMealCount;
    final mealPct = planned > 0 ? (completed / planned).clamp(0.0, 1.0) : 0.0;
    final calTarget = _today.targetCalories > 0 ? _today.targetCalories : _plan!.dailyCalories;
    final calPct = calTarget > 0
        ? (_today.caloriesConsumed / calTarget).clamp(0.0, 1.0)
        : 0.0;
    final waterTarget = _today.targetWaterMl > 0 ? _today.targetWaterMl : 2000;
    final waterPct = (_today.waterMl / waterTarget).clamp(0.0, 1.0);
    final completionPct = _dailyMealPercent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  planned == 0
                      ? 'No meals planned'
                      : '$completed/$planned meals completed',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              Text(
                '$completionPct%',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _progressMeter(
            isDark,
            label: 'Meal completion',
            detail: '$completed of $planned',
            value: mealPct,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 10),
          _progressMeter(
            isDark,
            label: 'Calories',
            detail: '${_today.caloriesConsumed} / $calTarget kcal',
            value: calPct,
            color: const Color(0xFFEF5350),
          ),
          const SizedBox(height: 10),
          _progressMeter(
            isDark,
            label: 'Water intake',
            detail: '${_today.waterMl} / $waterTarget ml',
            value: waterPct,
            color: const Color(0xFF0288D1),
          ),
        ],
      ),
    );
  }

  Widget _progressMeter(
    bool isDark, {
    required String label,
    required String detail,
    required double value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            Text(detail, style: CoachDashboardTheme.bodyMuted(isDark).copyWith(fontSize: 11)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: isDark ? Colors.white12 : Colors.black12,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _daySelector(bool isDark) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = _browseDay == i;
          final done = _dayCompleted[i] == true;
          final isToday = i == _todayDow;
          final locked = _isFutureDay(i);
          final dayDate = _dateForDay(i);
          return Material(
            color: selected
                ? CoachDashboardTheme.primary
                : (isDark ? const Color(0xFF181B24) : Colors.white),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _selectBrowseDay(i),
              child: Container(
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? CoachDashboardTheme.primary
                        : (isToday
                            ? CoachDashboardTheme.accent.withValues(alpha: 0.7)
                            : (isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB))),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DietDay.dayNames[i].substring(0, 3),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: selected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dayDate != null ? '${dayDate.month}/${dayDate.day}' : '—',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white70
                            : (isDark ? Colors.white54 : Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      done
                          ? Icons.check_circle
                          : (locked
                              ? Icons.lock_outline_rounded
                              : (isToday ? Icons.today_rounded : Icons.circle_outlined)),
                      size: 16,
                      color: selected
                          ? Colors.white
                          : (done
                              ? const Color(0xFF10B981)
                              : (locked
                                  ? (isDark ? Colors.white30 : Colors.black26)
                                  : (isDark ? Colors.white38 : Colors.black38))),
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

  Widget _singleDayBanner(bool isDark) {
    final dayName = _plan!.targetDayName ??
        (_plan!.targetDayOfWeek != null
            ? DietDay.dayNames[_plan!.targetDayOfWeek!.clamp(0, 6)]
            : 'Assigned day');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_rounded, color: Color(0xFF10B981)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Single-day plan · $dayName',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealExpandableCard(String type, bool isDark) {
    final meal = _mealOfType(type) ??
        (_mealsOfType(type).isNotEmpty ? _mealsOfType(type).first : null);
    final snacks = type == 'snacks' ? _mealsOfType('snacks').where((m) => m.hasContent).toList() : const <DietMeal>[];
    final completed = _mealFollowed[type] == true;
    final expanded = _expandedMealCards.contains(type);
    final label = _labelForType(type);
    final name = meal?.name.trim() ?? '';
    final canToggle = _canCheckInForBrowseDay && !_savingMeal;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: CoachDashboardTheme.cardDecoration(isDark).copyWith(
        border: Border.all(
          color: completed
              ? const Color(0xFF10B981).withValues(alpha: 0.45)
              : (isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB)),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedMealCards.remove(type);
                } else {
                  _expandedMealCards.add(type);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: !_canCheckInForBrowseDay
                        ? 'Locked until this day’s date'
                        : (completed ? 'Mark incomplete' : 'Mark complete'),
                    onPressed: canToggle ? () => _toggleMeal(type, !completed) : null,
                    icon: Icon(
                      !_canCheckInForBrowseDay
                          ? Icons.lock_outline_rounded
                          : (completed ? Icons.check_circle : Icons.circle_outlined),
                      color: completed
                          ? const Color(0xFF10B981)
                          : (isDark ? Colors.white38 : Colors.black38),
                      size: 28,
                    ),
                  ),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                    child: Icon(_iconForType(type), color: const Color(0xFF10B981), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            decoration: completed ? TextDecoration.lineThrough : null,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          name.isNotEmpty && name.toLowerCase() != label.toLowerCase()
                              ? name
                              : (completed ? 'Completed' : 'Tap checkmark when done'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: completed
                                ? const Color(0xFF10B981)
                                : (isDark ? Colors.white54 : Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (meal != null && meal.calories > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        '${meal.calories} kcal',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                  Icon(
                    expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: type == 'snacks' && snacks.length > 1
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final s in snacks) _mealDetailBlock(s, isDark, showTypeLabel: false),
                      ],
                    )
                  : (meal == null || !meal.hasContent)
                      ? Text('No details from your coach for this meal.', style: CoachDashboardTheme.bodyMuted(isDark))
                      : _mealDetailBlock(meal, isDark, showTypeLabel: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mealDetailBlock(DietMeal meal, bool isDark, {bool showTypeLabel = true}) {
    final name = meal.name.trim();
    final label = _labelForType(meal.type);
    final desc = meal.description.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTypeLabel)
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (name.isNotEmpty && name.toLowerCase() != label.toLowerCase())
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          if (meal.foodItems.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Food items', style: CoachDashboardTheme.bodyMuted(isDark).copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            ...meal.foodItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $item', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
              ),
            ),
          ],
          if (desc.isNotEmpty && meal.foodItems.isEmpty) ...[
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
          ],
          if (meal.portionSize.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Serving: ${meal.portionSize}',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
            ),
          ],
          if (meal.macrosLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meal.macrosLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
          ],
          if (meal.mealNotes.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Notes: ${meal.mealNotes}',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? Colors.white54 : Colors.black54),
            ),
          ],
          if (meal.prepInstructions.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Prep: ${meal.prepInstructions}',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
            ),
          ],
          if (meal.reminderTime.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Time: ${meal.reminderTime}',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _markDayCompleteTile(bool isDark) {
    final done = _dayCompleted[_browseDay] == true;
    final locked = !_canCheckInForBrowseDay;
    final label = _dayAndDateLabel(_browseDay);
    return Container(
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: CheckboxListTile(
        value: done,
        onChanged: (_savingMeal || locked)
            ? null
            : (v) => _toggleDay(_browseDay, v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: const Color(0xFF10B981),
        secondary: locked
            ? Icon(Icons.lock_outline_rounded, color: isDark ? Colors.white38 : Colors.black38)
            : null,
        title: Text(
          locked ? '$label · Locked' : 'Mark $label complete',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          locked
              ? 'Check-in unlocks on this day’s date'
              : (done ? 'Day checked off' : 'Optional — mark when you finish the day'),
          style: CoachDashboardTheme.bodyMuted(isDark),
        ),
      ),
    );
  }

  Widget _coachNotesCard(bool isDark) {
    final notes = _dayOrPlanNotes();
    return Container(
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _coachNotesExpanded = !_coachNotesExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.notes_rounded, color: CoachDashboardTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _coachNotesExpanded ? 'Hide coach notes' : 'Tap to read coach notes',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(
                    _coachNotesExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ],
              ),
            ),
          ),
          if (_coachNotesExpanded) ...[
            Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Text(
                notes,
                style: TextStyle(height: 1.4, color: isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _weeklyProgressCard(bool isDark) {
    return Container(
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _weeklyProgressExpanded = !_weeklyProgressExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('This week', style: TextStyle(fontWeight: FontWeight.w800)),
                        Text(
                          '$_completedDays of $_daysPlanned days complete · $_weeklyAverage% weekly avg',
                          style: CoachDashboardTheme.bodyMuted(isDark),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _weeklyProgressExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ],
              ),
            ),
          ),
          if (_weeklyProgressExpanded) ...[
            Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Column(
                children: [
                  for (var i = 0; i < 7; i++)
                    ListTile(
                      dense: true,
                      onTap: () => _selectBrowseDay(i),
                      leading: Icon(
                        _dayCompleted[i] == true
                            ? Icons.check_circle
                            : (_isFutureDay(i)
                                ? Icons.lock_outline_rounded
                                : (i == _todayDow
                                    ? Icons.today_rounded
                                    : Icons.circle_outlined)),
                        color: _dayCompleted[i] == true
                            ? const Color(0xFF10B981)
                            : (i == _todayDow
                                ? CoachDashboardTheme.accent
                                : (isDark ? Colors.white38 : Colors.black38)),
                      ),
                      title: Text(
                        _dayAndDateLabel(i),
                        style: TextStyle(
                          fontWeight: _browseDay == i ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        _dayCompleted[i] == true
                            ? 'Completed'
                            : (_isFutureDay(i)
                                ? 'Upcoming · locked'
                                : (i == _todayDow
                                    ? 'Today · ${_weeklyDayMealSummary(i)}'
                                    : _weeklyDayMealSummary(i))),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CoachDashboardTheme.bodyMuted(isDark).copyWith(fontSize: 11),
                      ),
                      trailing: _browseDay == i
                          ? const Icon(Icons.chevron_right_rounded, color: CoachDashboardTheme.primary)
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _weeklyDayMealSummary(int dayIndex) {
    final meals = _plan?.mealsForDay(dayIndex) ?? const <DietMeal>[];
    final planned = meals.where((m) => m.hasContent).length;
    if (planned == 0) return 'No meals planned';
    final entries = _dayMealAdherence[dayIndex];
    var done = 0;
    if (entries != null) {
      done = entries.where((e) => e['followed'] == true).length;
    } else if (dayIndex == _todayDow) {
      done = _today.mealAdherence.where((e) => e['followed'] == true).length;
    }
    if (_dayCompleted[dayIndex] == true) return 'Day complete · $planned meals';
    return '$done/$planned meals checked';
  }

  Widget _emptyStateCard(bool isDark, {required IconData icon, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        children: [
          Icon(icon, size: 36, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: CoachDashboardTheme.bodyMuted(isDark)),
        ],
      ),
    );
  }

  DietMeal? _mealOfType(String type) {
    for (final m in _browseMeals) {
      if (m.type == type && m.hasContent) return m;
    }
    for (final m in _browseMeals) {
      if (m.type == type) return m;
    }
    return null;
  }

  List<DietMeal> _mealsOfType(String type) =>
      _browseMeals.where((m) => m.type == type).toList();

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


  List<DietMeal> get _checkInMeals {
    if (_plan == null) return const [];
    if (_plan!.isWeekly) return _plan!.mealsForDay(_browseDay);
    return _plan!.mealsForDay(_todayDow);
  }

  int get _consumedCaloriesFromPlan {
    final types = _plannedMealTypes();
    if (types.isEmpty) return 0;

    final meals = _checkInMeals.where((m) => m.hasContent).toList();
    final anyExplicit = meals.any((m) => m.calories > 0);
    final daily = _plan?.dailyCalories ?? _today.targetCalories;
    final fallbackPerType =
        !anyExplicit && daily > 0 ? (daily / types.length).round() : 0;

    var total = 0;
    for (final type in types) {
      if (_mealFollowed[type] != true) continue;
      final typeCals = meals
          .where((m) => m.type == type)
          .fold<int>(0, (sum, m) => sum + m.calories);
      total += typeCals > 0 ? typeCals : fallbackPerType;
    }
    return total;
  }

  int get _consumedProteinFromPlan {
    var total = 0;
    for (final meal in _checkInMeals) {
      if (!meal.hasContent) continue;
      if (_mealFollowed[meal.type] == true) total += meal.protein;
    }
    return total;
  }

  int get _consumedCarbsFromPlan {
    var total = 0;
    for (final meal in _checkInMeals) {
      if (!meal.hasContent) continue;
      if (_mealFollowed[meal.type] == true) total += meal.carbs;
    }
    return total;
  }

  int get _consumedFatsFromPlan {
    var total = 0;
    for (final meal in _checkInMeals) {
      if (!meal.hasContent) continue;
      if (_mealFollowed[meal.type] == true) total += meal.fats;
    }
    return total;
  }

  DietTodayProgress _todayWithMealProgress({
    int? caloriesConsumed,
    int? mealsCompleted,
    int? mealsPlanned,
    int? dailyGoalPercent,
    int? adherencePercent,
    bool? followedPlan,
    int? proteinConsumed,
    int? carbsConsumed,
    int? fatsConsumed,
  }) {
    final planned = mealsPlanned ?? _plannedMealCount;
    final completed = mealsCompleted ?? _completedMealCount;
    final pct = dailyGoalPercent ??
        adherencePercent ??
        (planned > 0 ? ((completed / planned) * 100).round() : 0);
    return _today.copyWith(
      caloriesConsumed: caloriesConsumed ?? _consumedCaloriesFromPlan,
      mealsCompleted: completed,
      mealsPlanned: planned,
      dailyGoalPercent: pct,
      adherencePercent: adherencePercent ?? pct,
      followedPlan: followedPlan ?? (planned > 0 && completed == planned),
      hasActivity: true,
      proteinConsumed: proteinConsumed ?? _consumedProteinFromPlan,
      carbsConsumed: carbsConsumed ?? _consumedCarbsFromPlan,
      fatsConsumed: fatsConsumed ?? _consumedFatsFromPlan,
    );
  }

  List<DietMeal> get _browseMeals {
    if (_plan == null) return const [];
    if (_plan!.isWeekly) return _plan!.mealsForDay(_browseDay);
    return _plan!.mealsForDay(_plan!.targetDayOfWeek ?? _browseDay);
  }

  List<String> _plannedMealTypes() {
    final types = <String>[];
    for (final meal in _checkInMeals) {
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
}
