import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../screens/dashboard/widgets/coach_home/coach_dashboard_theme.dart';

class CoachAppointmentDaysDisplay extends StatelessWidget {
  final List<dynamic>? appointmentDays;
  final List<dynamic>? dayAvailability;
  final int? appointmentDurationMinutes;
  final bool compact;
  final bool isDark;

  const CoachAppointmentDaysDisplay({
    super.key,
    required this.appointmentDays,
    this.dayAvailability,
    this.appointmentDurationMinutes,
    this.compact = false,
    this.isDark = false,
  });

  static List<String> parseDays(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((d) => d.toString()).where((d) => d.isNotEmpty).toList();
  }

  static List<String> configuredDaysFromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return [];
    return parseDays(profile['appointmentDays']);
  }

  static List<String> daysFromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return [];
    final appointment = parseDays(profile['appointmentDays']);
    if (appointment.isNotEmpty) return appointment;
    return parseDays(profile['workingDays']);
  }

  static List<String> daysFromCoach(dynamic coach) {
    if (coach is! Map) return [];
    final profile = coach['profile'];
    if (profile is Map<String, dynamic>) return daysFromProfile(profile);
    if (profile is Map) return daysFromProfile(Map<String, dynamic>.from(profile));
    return [];
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

  static String? hoursLabelForDay(String day, List<dynamic>? availability) {
    if (availability is! List) return null;
    for (final entry in availability) {
      if (entry is! Map) continue;
      if (entry['day']?.toString() != day) continue;
      final start = entry['start']?.toString();
      final end = entry['end']?.toString();
      if (start == null || end == null || start.isEmpty || end.isEmpty) return null;
      return '${_formatTime(start)} – ${_formatTime(end)}';
    }
    return null;
  }

  static String _formatTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final dt = DateTime(2000, 1, 1, hour, minute);
    return DateFormat.jm().format(dt);
  }

  static String shortLabel(List<String> days) {
    if (days.isEmpty) return '';
    final count = days.length;
    return 'Books $count day${count == 1 ? '' : 's'} a week';
  }

  @override
  Widget build(BuildContext context) {
    final days = parseDays(appointmentDays);
    if (days.isEmpty) return const SizedBox.shrink();

    final dark = isDark || Theme.of(context).brightness == Brightness.dark;

    if (compact) {
      return Row(
        children: [
          Icon(Icons.event_available_rounded, size: 14, color: CoachDashboardTheme.primary),
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
            Icon(Icons.event_available_rounded, size: 18, color: CoachDashboardTheme.primary),
            const SizedBox(width: 8),
            Text(
              'Appointment Days',
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
          'Members can book on these days only.',
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
                color: CoachDashboardTheme.primary.withValues(alpha: dark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CoachDashboardTheme.primary.withValues(alpha: 0.25)),
              ),
              child: Text(
                dayAbbrev(day),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CoachDashboardTheme.primary,
                ),
              ),
            );
          }).toList(),
        ),
        if (dayAvailability != null && dayAvailability!.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...days.map((day) {
            final hours = hoursLabelForDay(day, dayAvailability);
            if (hours == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: dark ? Colors.white38 : CoachDashboardTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$day · $hours',
                      style: TextStyle(
                        fontSize: 12,
                        color: dark ? Colors.white70 : CoachDashboardTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        if (appointmentDurationMinutes != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 14, color: dark ? Colors.white38 : CoachDashboardTheme.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Duration: $appointmentDurationMinutes minutes',
                  style: TextStyle(
                    fontSize: 12,
                    color: dark ? Colors.white70 : CoachDashboardTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
