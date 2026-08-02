import 'package:flutter/material.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';
import '../../../models/user_model.dart';
import '../../../models/progress_model.dart';
import '../../../models/activity_log_model.dart';
import '../../../services/api_service.dart';
import '../../../widgets/scrollable_body.dart';
import '../../../widgets/animations/animations.dart';
import '../user_diet_plan_screen.dart';
import '../../../utils/share_helpers.dart';
import '../invite_friends_screen.dart';

class HomeTab extends StatefulWidget {
  final User user;
  final VoidCallback? onOpenDietPlan;
  final VoidCallback? onOpenMenu;
  final VoidCallback? onOpenProgress;
  final VoidCallback? onOpenWorkouts;

  const HomeTab({
    super.key,
    required this.user,
    this.onOpenDietPlan,
    this.onOpenMenu,
    this.onOpenProgress,
    this.onOpenWorkouts,
  });

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  ProgressData? _progressData;
  Map<String, dynamic>? _coachingData;
  Map<String, dynamic>? _dietToday;
  Map<String, dynamic>? _dietPlan;
  List<Map<String, dynamic>> _todayWorkouts = [];
  int _workoutCompletionPercent = 0;
  int? _stepsToday;
  num? _heartRate;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  static const _mealOrder = ['breakfast', 'lunch', 'dinner', 'snacks'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _fetchAll();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> refresh({bool showFeedback = false}) =>
      _fetchAll(isRefresh: true, showFeedback: showFeedback);

  Future<void> _fetchAll({bool isRefresh = false, bool showFeedback = false}) async {
    final hadData = _progressData != null || _dietToday != null;

    if (!isRefresh && !hadData) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else if (isRefresh) {
      setState(() {
        _errorMessage = null;
        _isRefreshing = true;
      });
    }

    try {
      final results = await Future.wait([
        _apiService.getProgress().then<ProgressData?>((v) => v).catchError((_) => null),
        _apiService.getUserCoaching().catchError((_) => null),
        _apiService.getUserDietProgress(days: 7).then<Map<String, dynamic>?>((v) => v).catchError((_) => null),
        _apiService.getUserWorkoutSchedules().then<Map<String, dynamic>?>((v) => v).catchError((_) => null),
        _apiService.getUserWorkoutProgress(days: 30).then<Map<String, dynamic>?>((v) => v).catchError((_) => null),
        _apiService.getUserDashboard().catchError((_) => null),
      ]);

      if (!mounted) return;

      final progress = results[0] as ProgressData?;
      final dietPayload = results[2] as Map<String, dynamic>?;
      final schedules = results[3] as Map<String, dynamic>?;
      final workoutProgress = results[4] as Map<String, dynamic>?;
      final userDash = results[5] as Map<String, dynamic>?;

      if (progress == null && dietPayload == null && !hadData) {
        throw Exception('Unable to load dashboard data');
      }

      final dietToday = dietPayload?['today'] is Map
          ? Map<String, dynamic>.from(dietPayload!['today'] as Map)
          : null;
      final dietPlan = dietPayload?['plan'] is Map
          ? Map<String, dynamic>.from(dietPayload!['plan'] as Map)
          : null;

      final todayWorkouts = _parseTodayWorkouts(schedules);
      final summary = workoutProgress?['summary'] as Map<String, dynamic>?;
      final workoutPct = (summary?['completionPercent'] as num?)?.toInt() ?? 0;

      final steps = _extractTodaySteps(userDash);
      final hr = _extractHeartRate(userDash, progress);

      setState(() {
        if (progress != null) _progressData = progress;
        _coachingData = results[1] as Map<String, dynamic>?;
        if (dietToday != null) _dietToday = dietToday;
        if (dietPlan != null) _dietPlan = dietPlan;
        _todayWorkouts = todayWorkouts;
        _workoutCompletionPercent = workoutPct.clamp(0, 100);
        _stepsToday = steps;
        _heartRate = hr;
        _isLoading = false;
        _isRefreshing = false;
      });

      if (!hadData && !isRefresh) {
        _animController.forward(from: 0);
      } else {
        _animController.value = 1.0;
      }

      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Dashboard updated'),
            backgroundColor: CoachDashboardTheme.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message = ApiService.friendlyError(e);
      if (hadData) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
        if (isRefresh || showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: CoachDashboardTheme.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = message;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _parseTodayWorkouts(Map<String, dynamic>? schedules) {
    if (schedules == null) return const [];
    final pending = (schedules['today'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final history = (schedules['history'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where(_isScheduleToday)
        .toList();
    final byId = <String, Map<String, dynamic>>{};
    for (final item in [...pending, ...history]) {
      final id = item['_id']?.toString() ?? item['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      byId[id] = item;
    }
    final list = byId.values.toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a['startDateTime']?.toString() ?? a['date']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse(b['startDateTime']?.toString() ?? b['date']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return da.compareTo(db);
      });
    return list;
  }

  bool _isScheduleToday(Map<String, dynamic> item) {
    final raw = item['startDateTime']?.toString() ?? item['date']?.toString() ?? '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return false;
    final local = dt.toLocal();
    final now = DateTime.now();
    return local.year == now.year && local.month == now.month && local.day == now.day;
  }

  int? _extractTodaySteps(Map<String, dynamic>? dash) {
    final trackings = dash?['dailyTrackings'];
    if (trackings is! List || trackings.isEmpty) return null;
    final now = DateTime.now();
    for (final raw in trackings) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final date = DateTime.tryParse(map['date']?.toString() ?? '');
      if (date == null) continue;
      final local = date.toLocal();
      if (local.year == now.year && local.month == now.month && local.day == now.day) {
        final steps = (map['steps'] as num?)?.toInt();
        return steps;
      }
    }
    // Most recent entry as fallback only if dated today failed
    return null;
  }

  num? _extractHeartRate(Map<String, dynamic>? dash, ProgressData? progress) {
    // Heart rate is not in current production APIs — only show if present.
    final trackings = dash?['dailyTrackings'];
    if (trackings is List) {
      for (final raw in trackings) {
        if (raw is! Map) continue;
        final hr = raw['heartRate'] ?? raw['heart_rate'] ?? raw['hr'];
        if (hr is num) return hr;
      }
    }
    final compliance = progress?.compliance;
    final hr = compliance?['heartRate'] ?? compliance?['heart_rate'];
    if (hr is num) return hr;
    return null;
  }

  num get _caloriesIn =>
      _progressData?.summary.caloriesIn ??
      (_dietToday?['caloriesConsumed'] as num?) ??
      0;

  num get _caloriesOut =>
      _progressData?.summary.caloriesOut ??
      (_dietToday?['caloriesBurned'] as num?) ??
      0;

  num get _hydration =>
      _progressData?.summary.hydration ??
      (_dietToday?['waterMl'] as num?) ??
      0;

  int get _targetCalories {
    final fromDiet = (_dietToday?['targetCalories'] as num?)?.toInt() ?? 0;
    if (fromDiet > 0) return fromDiet;
    return (_dietPlan?['dailyCalories'] as num?)?.toInt() ?? 0;
  }

  int get _targetWater => (_dietToday?['targetWaterMl'] as num?)?.toInt() ?? 2000;

  int get _mealsCompleted => (_dietToday?['mealsCompleted'] as num?)?.toInt() ?? 0;
  int get _mealsPlanned => (_dietToday?['mealsPlanned'] as num?)?.toInt() ?? 0;

  int get _workoutsCompleted => (_dietToday?['workoutsCompleted'] as num?)?.toInt() ??
      _todayWorkouts.where((w) => w['completion']?['status'] == 'completed').length;

  int get _workoutsPlanned {
    final fromDiet = (_dietToday?['workoutsPlanned'] as num?)?.toInt() ?? 0;
    if (fromDiet > 0) return fromDiet;
    return _todayWorkouts.isEmpty ? 0 : _todayWorkouts.length;
  }

  int get _dailyGoalPercent => (_dietToday?['dailyGoalPercent'] as num?)?.toInt() ?? 0;

  int get _workoutMinutesToday {
    var total = 0;
    final now = DateTime.now();
    final activities = _progressData?.recentActivities ?? const <ActivityLog>[];
    for (final a in activities) {
      final d = a.date.toLocal();
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        total += a.durationMinutes;
      }
    }
    if (total > 0) return total;
    for (final w in _todayWorkouts) {
      total += (w['durationMinutes'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  List<Map<String, dynamic>> get _todayMeals {
    final summary = _dietToday?['mealSummary'];
    if (summary is Map && summary['meals'] is List) {
      return (summary['meals'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    final adherence = _dietToday?['mealAdherence'];
    if (adherence is List) {
      return adherence.whereType<Map>().map((e) {
        final m = Map<String, dynamic>.from(e);
        final type = m['type']?.toString() ?? '';
        return {
          'type': type,
          'label': m['label'] ?? _mealLabel(type),
          'completed': m['completed'] == true || m['followed'] == true,
        };
      }).toList();
    }
    return const [];
  }

  String _mealLabel(String type) => switch (type) {
        'breakfast' => 'Breakfast',
        'lunch' => 'Lunch',
        'dinner' => 'Dinner',
        'snacks' => 'Snacks',
        _ => type.isEmpty ? 'Meal' : type,
      };

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[now.weekday - 1]}, ${months[now.month]} ${now.day}';
  }

  Future<void> _addWater(double ml) async {
    try {
      final ok = await _apiService.logWater(ml);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${ml.toInt()} ml water'),
            backgroundColor: const Color(0xFF0288D1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        await _fetchAll(isRefresh: true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiService.friendlyError(e)),
          backgroundColor: CoachDashboardTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showAddWaterDialog() async {
    final ctrl = TextEditingController();
    final ml = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add water'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount (ml)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ml != null) await _addWater(ml);
  }

  Future<void> _showLogMealDialog() async {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log meal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Meal name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: calCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Calories', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              if (double.tryParse(calCtrl.text.trim()) == null) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _apiService.logMeal(
        mealName: nameCtrl.text.trim(),
        calories: double.parse(calCtrl.text.trim()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal logged'),
          backgroundColor: CoachDashboardTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _fetchAll(isRefresh: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiService.friendlyError(e)),
          backgroundColor: CoachDashboardTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openDiet() {
    if (widget.onOpenDietPlan != null) {
      widget.onOpenDietPlan!();
    } else {
      AppNavigator.push(context, const UserDietPlanScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showInitialLoading = _isLoading && _progressData == null && _dietToday == null;
    final showInitialError = _errorMessage != null && _progressData == null && _dietToday == null;

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      body: AnimatedContentSwitcher(
        child: showInitialLoading
            ? const LottieLoadingCenter(key: ValueKey('loading'))
            : showInitialError
                ? _buildError(key: const ValueKey('error'))
                : FadeTransition(
                    key: const ValueKey('content'),
                    opacity: _fadeAnim,
                    child: PremiumRefreshIndicator(
                      onRefresh: () => _fetchAll(isRefresh: true),
                      child: CustomScrollView(
                        physics: dashboardScrollPhysics,
                        slivers: [
                          _buildHero(isDark),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                if (_isRefreshing) const LinearProgressIndicator(minHeight: 2),
                                if (_isRefreshing) const SizedBox(height: 10),
                                _sectionLabel(isDark, 'Today at a glance'),
                                const SizedBox(height: 8),
                                _buildStatsGrid(isDark),
                                const SizedBox(height: 16),
                                _sectionLabel(isDark, 'Daily progress'),
                                const SizedBox(height: 8),
                                _buildProgressCard(isDark),
                                const SizedBox(height: 16),
                                _sectionLabel(isDark, 'Quick actions'),
                                const SizedBox(height: 8),
                                _buildQuickActions(isDark),
                                const SizedBox(height: 16),
                                _sectionLabel(isDark, "Today's diet plan"),
                                const SizedBox(height: 8),
                                _buildDietSection(isDark),
                                const SizedBox(height: 16),
                                _sectionLabel(isDark, "Today's workout"),
                                const SizedBox(height: 8),
                                _buildWorkoutSection(isDark),
                                const SizedBox(height: 16),
                                _sectionLabel(isDark, 'Insights'),
                                const SizedBox(height: 8),
                                _buildInsightsCard(isDark),
                                const SizedBox(height: 12),
                                _buildShareCard(isDark),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _sectionLabel(bool isDark, String title) {
    return Text(title, style: CoachDashboardTheme.sectionTitle(isDark));
  }

  Widget _buildError({Key? key}) {
    return ScrollableCenter(
      key: key,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xFFFF6B6B)),
        const SizedBox(height: 12),
        Text(
          _errorMessage ?? 'Something went wrong',
          textAlign: TextAlign.center,
          style: CoachDashboardTheme.bodyMuted(false),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _fetchAll,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          style: FilledButton.styleFrom(backgroundColor: CoachDashboardTheme.primary),
        ),
      ]),
    );
  }

  SliverToBoxAdapter _buildHero(bool isDark) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: CoachDashboardTheme.headerGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.onOpenMenu != null)
                  IconButton(
                    onPressed: widget.onOpenMenu,
                    icon: const Icon(Icons.menu_rounded, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting(), style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                      Text(
                        widget.user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_formattedDate(), style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _heroChip(Icons.restaurant_rounded, '${_caloriesIn.toInt()}', 'kcal in')),
                const SizedBox(width: 8),
                Expanded(child: _heroChip(Icons.local_fire_department_rounded, '${_caloriesOut.toInt()}', 'kcal out')),
                const SizedBox(width: 8),
                Expanded(child: _heroChip(Icons.water_drop_rounded, '${_hydration.toInt()}', 'ml water')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    final tiles = <_StatTile>[
      _StatTile('Calories In', '${_caloriesIn.toInt()}', 'kcal', Icons.restaurant_rounded, const Color(0xFFEF5350)),
      _StatTile('Calories Out', '${_caloriesOut.toInt()}', 'kcal', Icons.local_fire_department_rounded, const Color(0xFFF57C00)),
      _StatTile('Water', '${_hydration.toInt()}', 'ml', Icons.water_drop_rounded, const Color(0xFF0288D1)),
      _StatTile('Workout time', '$_workoutMinutesToday', 'min', Icons.timer_outlined, CoachDashboardTheme.primary),
      if (_stepsToday != null)
        _StatTile('Steps', '$_stepsToday', '', Icons.directions_walk_rounded, const Color(0xFF059669)),
      if (_heartRate != null)
        _StatTile('Heart rate', '${_heartRate!.toInt()}', 'bpm', Icons.favorite_rounded, const Color(0xFFDB2777)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cross = constraints.maxWidth >= 520 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: cross == 3 ? 1.45 : 1.55,
          ),
          itemBuilder: (_, i) {
            final t = tiles[i];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: CoachDashboardTheme.cardDecoration(isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(t.icon, color: t.color, size: 20),
                  const Spacer(),
                  Text(t.label, style: CoachDashboardTheme.bodyMuted(isDark).copyWith(fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    t.unit.isEmpty ? t.value : '${t.value} ${t.unit}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProgressCard(bool isDark) {
    final calTarget = _targetCalories > 0 ? _targetCalories : 2000;
    final calPct = (calTarget > 0 ? (_caloriesIn / calTarget) : 0.0).clamp(0.0, 1.0);
    final waterPct = (_hydration / _targetWater).clamp(0.0, 1.0);
    final workoutPct = _workoutsPlanned > 0
        ? (_workoutsCompleted / _workoutsPlanned).clamp(0.0, 1.0)
        : (_workoutCompletionPercent / 100).clamp(0.0, 1.0);
    final goalPct = (_dailyGoalPercent / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        children: [
          _progressRow(
            isDark,
            'Calories',
            '${_caloriesIn.toInt()} / $calTarget kcal',
            calPct,
            const Color(0xFFEF5350),
          ),
          const SizedBox(height: 12),
          _progressRow(
            isDark,
            'Water intake',
            '${_hydration.toInt()} / $_targetWater ml',
            waterPct,
            const Color(0xFF0288D1),
          ),
          const SizedBox(height: 12),
          _progressRow(
            isDark,
            'Workout progress',
            _workoutsPlanned > 0
                ? '$_workoutsCompleted / $_workoutsPlanned today'
                : '$_workoutCompletionPercent% overall',
            workoutPct,
            CoachDashboardTheme.primary,
          ),
          const SizedBox(height: 12),
          _progressRow(
            isDark,
            'Daily goals',
            '$_dailyGoalPercent%',
            goalPct,
            const Color(0xFF059669),
          ),
        ],
      ),
    );
  }

  Widget _progressRow(bool isDark, String title, String subtitle, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Text(subtitle, style: CoachDashboardTheme.bodyMuted(isDark).copyWith(fontSize: 11)),
          ],
        ),
        const SizedBox(height: 6),
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

  Widget _buildQuickActions(bool isDark) {
    final actions = [
      (Icons.restaurant_rounded, 'Log Meal', _showLogMealDialog, const Color(0xFFEF5350)),
      (Icons.water_drop_rounded, 'Add Water', _showAddWaterDialog, const Color(0xFF0288D1)),
      (Icons.fitness_center_rounded, 'Start Workout', () => widget.onOpenWorkouts?.call(), CoachDashboardTheme.primary),
      (Icons.bar_chart_rounded, 'View Progress', () => widget.onOpenProgress?.call(), const Color(0xFF059669)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 420;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in actions)
              SizedBox(
                width: wide ? (constraints.maxWidth - 24) / 4 : (constraints.maxWidth - 8) / 2,
                child: Material(
                  color: isDark ? const Color(0xFF181B24) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  elevation: isDark ? 0 : 0.5,
                  shadowColor: Colors.black26,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: a.$3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: [
                          Icon(a.$1, color: a.$4, size: 22),
                          const SizedBox(height: 6),
                          Text(
                            a.$2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDietSection(bool isDark) {
    final meals = _todayMeals;
    final ordered = <Map<String, dynamic>>[];
    for (final type in _mealOrder) {
      Map<String, dynamic>? match;
      for (final m in meals) {
        if (m['type']?.toString() == type) {
          match = m;
          break;
        }
      }
      if (match != null) ordered.add(match);
    }
    for (final m in meals) {
      if (!_mealOrder.contains(m['type']?.toString())) ordered.add(m);
    }

    return Container(
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 4, 8, 0),
            title: Text(
              _dietPlan?['title']?.toString() ?? 'Assigned diet plan',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text(
              ordered.isEmpty
                  ? 'No meals planned for today'
                  : '$_mealsCompleted of $_mealsPlanned meals complete',
              style: CoachDashboardTheme.bodyMuted(isDark),
            ),
            trailing: TextButton(onPressed: _openDiet, child: const Text('Open')),
          ),
          if (ordered.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                'Open Diet Plan when your coach assigns meals.',
                style: CoachDashboardTheme.bodyMuted(isDark),
              ),
            )
          else
            ...ordered.map((m) {
              final done = m['completed'] == true;
              final label = m['label']?.toString() ?? _mealLabel(m['type']?.toString() ?? '');
              return ListTile(
                dense: true,
                leading: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? CoachDashboardTheme.success : Colors.grey,
                ),
                title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, decoration: done ? TextDecoration.lineThrough : null)),
                subtitle: Text(done ? 'Completed' : 'Not completed', style: TextStyle(fontSize: 11, color: done ? CoachDashboardTheme.success : CoachDashboardTheme.danger)),
                onTap: _openDiet,
              );
            }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildWorkoutSection(bool isDark) {
    final doneCount = _todayWorkouts.where((w) => w['completion']?['status'] == 'completed').length;
    return Container(
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 4, 8, 0),
            title: const Text("Today's sessions", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Text(
              _todayWorkouts.isEmpty
                  ? 'No workouts scheduled today'
                  : '$doneCount of ${_todayWorkouts.length} completed',
              style: CoachDashboardTheme.bodyMuted(isDark),
            ),
            trailing: TextButton(
              onPressed: widget.onOpenWorkouts,
              child: const Text('Schedule'),
            ),
          ),
          if (_todayWorkouts.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                'When your coach schedules a session, it will appear here.',
                style: CoachDashboardTheme.bodyMuted(isDark),
              ),
            )
          else
            ..._todayWorkouts.map((w) {
              final title = w['title']?.toString() ?? w['workoutTemplate']?['title']?.toString() ?? 'Workout';
              final completed = w['completion']?['status'] == 'completed';
              final mins = (w['durationMinutes'] as num?)?.toInt();
              final start = DateTime.tryParse(w['startDateTime']?.toString() ?? '');
              final timeLabel = start == null
                  ? null
                  : '${start.toLocal().hour.toString().padLeft(2, '0')}:${start.toLocal().minute.toString().padLeft(2, '0')}';
              return ListTile(
                dense: true,
                leading: Icon(
                  completed ? Icons.check_circle : Icons.fitness_center_rounded,
                  color: completed ? CoachDashboardTheme.success : CoachDashboardTheme.primary,
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  [
                    if (timeLabel != null) timeLabel,
                    if (mins != null && mins > 0) '$mins min',
                    completed ? 'Completed' : 'Pending',
                  ].join(' · '),
                  style: TextStyle(fontSize: 11, color: completed ? CoachDashboardTheme.success : null),
                ),
                onTap: widget.onOpenWorkouts,
              );
            }),
          if (_workoutsPlanned > 0 || _workoutCompletionPercent > 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _workoutsPlanned > 0
                      ? (_workoutsCompleted / _workoutsPlanned).clamp(0.0, 1.0)
                      : (_workoutCompletionPercent / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                  color: CoachDashboardTheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightsCard(bool isDark) {
    final reports = _progressData?.reports ?? const <String>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.purple.shade400, size: 20),
              const SizedBox(width: 8),
              Text(
                'Personalized tips',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (reports.isEmpty)
            Text(
              'Log meals, water, and workouts to unlock insights.',
              style: CoachDashboardTheme.bodyMuted(isDark),
            )
          else
            ...reports.take(4).map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: CoachDashboardTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildShareCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Share your wins', style: CoachDashboardTheme.sectionTitle(isDark).copyWith(fontSize: 14)),
          const SizedBox(height: 4),
          Text('Create a branded card or invite a friend.', style: CoachDashboardTheme.bodyMuted(isDark)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => shareVitalCard(context, type: 'progress'),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Share'),
              ),
              OutlinedButton.icon(
                onPressed: () => shareVitalCard(context, type: 'weekly'),
                icon: const Icon(Icons.calendar_view_week_rounded, size: 18),
                label: const Text('Weekly'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InviteFriendsScreen()),
                  );
                },
                style: FilledButton.styleFrom(backgroundColor: CoachDashboardTheme.primary),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Invite'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  const _StatTile(this.label, this.value, this.unit, this.icon, this.color);
}
