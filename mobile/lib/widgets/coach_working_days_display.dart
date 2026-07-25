import 'package:flutter/material.dart';

import '../screens/dashboard/widgets/coach_home/coach_dashboard_theme.dart';

class CoachWorkingDaysDisplay extends StatelessWidget {
  final List<dynamic>? workingDays;
  final bool compact;
  final bool isDark;

  const CoachWorkingDaysDisplay({
    super.key,
    required this.workingDays,
    this.compact = false,
    this.isDark = false,
  });

  static List<String> parseDays(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((d) => d.toString()).where((d) => d.isNotEmpty).toList();
  }

  static List<String> daysFromCoach(dynamic coach) {
    if (coach is! Map) return [];
    final profile = coach['profile'];
    if (profile is Map) return parseDays(profile['workingDays']);
    return [];
  }

  static String shortLabel(List<String> days) {
    if (days.isEmpty) return '';
    final count = days.length;
    return 'Works $count day${count == 1 ? '' : 's'} a week';
  }

  static String dayAbbrev(String day) {
    const map = {
      'Monday': 'Mon',
      'Tuesday': 'Tue',
      'Wednesday': 'Wed',
      'Thursday': 'Thu',
      'Friday': 'Fri',
      'Saturday': 'Sat',
      'Sunday': 'Sun',
    };
    return map[day] ?? day.substring(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    final days = parseDays(workingDays);
    if (days.isEmpty) return const SizedBox.shrink();

    final dark = isDark || Theme.of(context).brightness == Brightness.dark;

    if (compact) {
      return Row(
        children: [
          Icon(Icons.calendar_today_rounded, size: 14, color: CoachDashboardTheme.accent),
          const SizedBox(width: 6),
          Text(
            shortLabel(days),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: dark ? Colors.white70 : CoachDashboardTheme.textSecondary,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 18, color: CoachDashboardTheme.accent),
            const SizedBox(width: 8),
            Text(
              'Working Days',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: dark ? Colors.white : CoachDashboardTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          shortLabel(days),
          style: TextStyle(
            fontSize: 12,
            color: dark ? Colors.white54 : CoachDashboardTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: days.map((day) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: CoachDashboardTheme.accent.withValues(alpha: dark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CoachDashboardTheme.accent.withValues(alpha: 0.25)),
              ),
              child: Text(
                dayAbbrev(day),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CoachDashboardTheme.accent,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
