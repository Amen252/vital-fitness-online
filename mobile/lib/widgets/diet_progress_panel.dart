import 'package:flutter/material.dart';

import '../models/diet_today_progress_model.dart';
import '../screens/dashboard/widgets/coach_home/coach_dashboard_theme.dart';

class DietProgressPanel extends StatelessWidget {
  final DietTodayProgress today;
  final int avgAdherence;
  final int weeklyAveragePercent;
  final List<String> mealTypes;
  final Map<String, bool> mealFollowed;
  final bool isDark;
  final VoidCallback? onRefresh;
  final bool shrinkWrap;
  final List<Widget> footer;
  final String? progressTitle;

  const DietProgressPanel({
    super.key,
    required this.today,
    this.avgAdherence = 0,
    this.weeklyAveragePercent = 0,
    this.mealTypes = const [],
    this.mealFollowed = const {},
    required this.isDark,
    this.onRefresh,
    this.shrinkWrap = false,
    this.footer = const [],
    this.progressTitle,
  });

  String _mealLabel(String type) {
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

  @override
  Widget build(BuildContext context) {
    final hasMealData = today.mealsPlanned > 0 || mealTypes.isNotEmpty;
    if (!today.hasActivity && avgAdherence == 0 && !hasMealData) {
      return _emptyState();
    }

    final mealPct = today.mealsPlanned > 0
        ? ((today.mealsCompleted / today.mealsPlanned) * 100).round()
        : 0;
    final remaining = (today.mealsPlanned - today.mealsCompleted).clamp(0, today.mealsPlanned);
    final mealProgressLabel = today.mealsPlanned > 0
        ? '${today.mealsCompleted} completed · $remaining remaining · $mealPct%'
        : 'No meals planned for this day';

    return ListView(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(18),
      children: [
        if (onRefresh != null)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Refresh progress',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        _overallCard(mealPct, mealProgressLabel, progressTitle),
        if (mealTypes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            progressTitle ?? 'Meal completion',
            style: CoachDashboardTheme.sectionTitle(isDark),
          ),
          const SizedBox(height: 8),
          ...mealTypes.map((type) {
            final done = mealFollowed[type] ?? _isMealCompletedInToday(type);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${done ? '✅' : '❌'} ${_mealLabel(type)} ${done ? 'completed' : 'not completed'}',
                style: TextStyle(
                  color: done ? CoachDashboardTheme.success : CoachDashboardTheme.danger,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 16),
        Text('Today', style: CoachDashboardTheme.sectionTitle(isDark)),
        const SizedBox(height: 10),
        _metricBar(
          icon: Icons.restaurant_rounded,
          label: 'Meals completed',
          current: today.mealsCompleted,
          target: today.mealsPlanned,
          unit: 'meals',
          progress: today.mealsProgress,
          color: CoachDashboardTheme.success,
        ),
        _metricBar(
          icon: Icons.local_fire_department_rounded,
          label: 'Calories',
          current: today.caloriesConsumed,
          target: today.targetCalories,
          unit: 'kcal',
          progress: today.caloriesProgress,
          color: CoachDashboardTheme.warning,
        ),
        _metricBar(
          icon: Icons.water_drop_rounded,
          label: 'Water',
          current: today.waterMl,
          target: today.targetWaterMl,
          unit: 'ml',
          progress: today.waterProgress,
          color: const Color(0xFF29B6F6),
        ),
        _metricBar(
          icon: Icons.fitness_center_rounded,
          label: 'Workouts',
          current: today.workoutsCompleted,
          target: today.workoutsPlanned,
          unit: 'sessions',
          progress: today.workoutsProgress,
          color: CoachDashboardTheme.primary,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: CoachDashboardTheme.cardDecoration(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${weeklyAveragePercent > 0 ? weeklyAveragePercent : avgAdherence}%',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: CoachDashboardTheme.primary),
              ),
              Text('Weekly diet plan completion', style: CoachDashboardTheme.bodyMuted(isDark)),
              if (avgAdherence > 0 && weeklyAveragePercent != avgAdherence)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('14-day average: $avgAdherence%', style: CoachDashboardTheme.bodyMuted(isDark)),
                ),
            ],
          ),
        ),
        ...footer,
      ],
    );
  }

  bool _isMealCompletedInToday(String type) {
    for (final entry in today.mealAdherence) {
      if (entry['type']?.toString() == type) return entry['followed'] == true;
    }
    return false;
  }

  Widget _emptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            if (onRefresh != null)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded)),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight.isFinite ? constraints.maxHeight : 320) - (onRefresh != null ? 56 : 0),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.insights_rounded, size: 56, color: isDark ? Colors.white24 : Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No meal check-ins yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        'Check off each meal after you complete it to track your daily progress.',
                        textAlign: TextAlign.center,
                        style: CoachDashboardTheme.bodyMuted(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _overallCard(int mealPct, String mealProgressLabel, [String? title]) {
    final pct = today.mealsPlanned > 0 ? mealPct : (today.hasActivity ? today.dailyGoalPercent : 0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title.isNotEmpty) ...[
            Text(title, style: CoachDashboardTheme.sectionTitle(isDark)),
            const SizedBox(height: 6),
          ],
          Text('$pct%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: CoachDashboardTheme.primary)),
          Text(
            today.mealsPlanned > 0 ? mealProgressLabel : 'Daily goal completion',
            style: CoachDashboardTheme.bodyMuted(isDark),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              color: CoachDashboardTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBar({
    required IconData icon,
    required String label,
    required int current,
    required int target,
    required String unit,
    required double progress,
    required Color color,
  }) {
    final valueLabel = target > 0 ? '$current / $target $unit' : '$current $unit';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(valueLabel, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
