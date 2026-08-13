import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';
import '../../../../utils/coach_thread_utils.dart';
import 'coach_dashboard_theme.dart';

class CoachStatCardData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const CoachStatCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });
}

class CoachQuickActionData {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const CoachQuickActionData({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class CoachHomeWelcomeHeader extends StatelessWidget {
  final String greeting;
  final String coachName;
  final String dateLabel;
  final String? subtitle;
  final VoidCallback onMenuTap;
  final VoidCallback onNotificationsTap;
  final bool isDark;

  const CoachHomeWelcomeHeader({
    super.key,
    required this.greeting,
    required this.coachName,
    required this.dateLabel,
    this.subtitle,
    required this.onMenuTap,
    required this.onNotificationsTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final initial = coachName.isNotEmpty ? coachName[0].toUpperCase() : 'C';

    return Container(
      decoration: BoxDecoration(
        gradient: CoachDashboardTheme.headerGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CoachDashboardTheme.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                onPressed: onMenuTap,
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                onPressed: onNotificationsTap,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: CoachDashboardTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      coachName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _headerChip(Icons.calendar_today_outlined, dateLabel),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Flexible(child: _headerChip(Icons.insights_outlined, subtitle!)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class CoachHomeSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String? trailing;
  final VoidCallback? onTrailingTap;
  final bool isDark;

  const CoachHomeSectionTitle({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    this.trailing,
    this.onTrailingTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: CoachDashboardTheme.sectionTitle(isDark)),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: CoachDashboardTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              trailing!,
              style: const TextStyle(color: CoachDashboardTheme.primary, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class CoachHomeStatsGrid extends StatelessWidget {
  final List<CoachStatCardData> stats;
  final bool isDark;
  final double maxWidth;

  const CoachHomeStatsGrid({
    super.key,
    required this.stats,
    required this.isDark,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: maxWidth >= 600 ? 4 : 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: maxWidth >= 600 ? 1.45 : 1.2,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final s = stats[index];
        return Container(
          decoration: CoachDashboardTheme.cardDecoration(isDark),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                Container(width: 4, color: s.color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(s.icon, size: 16, color: s.color),
                            const Spacer(),
                            Text(s.value, style: CoachDashboardTheme.metricValue(s.color)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(s.label, style: CoachDashboardTheme.metricLabel(isDark)),
                        if (s.subtitle != null)
                          Text(
                            s.subtitle!,
                            style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : CoachDashboardTheme.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CoachHomeQuickActions extends StatelessWidget {
  final List<CoachQuickActionData> actions;
  final bool isDark;
  final double maxWidth;

  const CoachHomeQuickActions({
    super.key,
    required this.actions,
    required this.isDark,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: actions.map((a) {
          final isLast = a == actions.last;
          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: a.onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: a.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(a.icon, color: a.color, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            a.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : CoachDashboardTheme.textPrimary,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? Colors.white24 : Colors.black26),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 66,
                  color: isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class CoachHomeProgressCharts extends StatelessWidget {
  final double performanceScore;
  final double attendanceRate;
  final double goalCompletionRate;
  final bool isDark;

  const CoachHomeProgressCharts({
    super.key,
    required this.performanceScore,
    required this.attendanceRate,
    required this.goalCompletionRate,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoachHomeSectionTitle(
            title: 'Progress Overview',
            icon: Icons.insights_rounded,
            iconColor: CoachDashboardTheme.success,
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(child: _miniBarChart('Performance', performanceScore, CoachDashboardTheme.primary, isDark)),
                const SizedBox(width: 12),
                Expanded(child: _miniBarChart('Attendance', attendanceRate, CoachDashboardTheme.accent, isDark)),
                const SizedBox(width: 12),
                Expanded(child: _miniBarChart('Goals', goalCompletionRate, CoachDashboardTheme.success, isDark)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _legend('Performance', performanceScore, CoachDashboardTheme.primary),
              _legend('Attendance', attendanceRate, CoachDashboardTheme.accent),
              _legend('Goals', goalCompletionRate, CoachDashboardTheme.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, double value, Color color) {
    return Column(
      children: [
        Text('${value.round()}%', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)),
      ],
    );
  }

  Widget _miniBarChart(String title, double percent, Color color, bool isDark) {
    final clamped = percent.clamp(0, 100).toDouble();
    return BarChart(
      BarChartData(
        maxY: 100,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        barGroups: [
          BarChartGroupData(
            x: 0,
            barRods: [
              BarChartRodData(
                toY: clamped,
                color: color,
                width: 28,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: 100,
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),
              ),
            ],
          ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
    );
  }
}

class CoachHomeNotificationsList extends StatelessWidget {
  final List<dynamic> notifications;
  final bool isDark;

  const CoachHomeNotificationsList({
    super.key,
    required this.notifications,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoachHomeSectionTitle(
            title: 'Notifications',
            icon: Icons.notifications_active_rounded,
            iconColor: CoachDashboardTheme.warning,
            trailing: notifications.isNotEmpty ? '${notifications.length}' : null,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          if (notifications.isEmpty)
            _emptyState(Icons.notifications_none_rounded, 'No new notifications', isDark)
          else
            ...notifications.take(4).map((n) {
              final message = n['message'] ?? 'Notification';
              final type = n['type'] ?? 'info';
              final read = n['read'] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: read
                      ? (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02))
                      : CoachDashboardTheme.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: read ? Colors.transparent : CoachDashboardTheme.warning.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(_iconForType(type), size: 20, color: CoachDashboardTheme.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: read ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'session':
      case 'reminder':
        return Icons.event_rounded;
      case 'assignment':
      case 'update':
        return Icons.assignment_rounded;
      case 'tip':
        return Icons.lightbulb_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }
}

class CoachHomeMessagesPreview extends StatelessWidget {
  final List<dynamic> threads;
  final bool isDark;
  final VoidCallback? onViewAll;

  const CoachHomeMessagesPreview({
    super.key,
    required this.threads,
    required this.isDark,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoachHomeSectionTitle(
            title: 'Recent Messages',
            icon: Icons.chat_bubble_rounded,
            iconColor: CoachDashboardTheme.pink,
            trailing: threads.isNotEmpty ? 'View all' : null,
            onTrailingTap: onViewAll,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          if (threads.isEmpty)
            _emptyState(Icons.chat_bubble_outline, 'No messages yet', isDark)
          else
            ...threads.take(3).map((t) {
              final thread = Map<String, dynamic>.from(t as Map);
              final name = CoachThreadUtils.clientName(thread);
              final preview = CoachThreadUtils.lastMessagePreview(thread);
              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: CoachDashboardTheme.pink.withValues(alpha: 0.15),
                  child: Text(initial, style: const TextStyle(color: CoachDashboardTheme.pink, fontWeight: FontWeight.bold)),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              );
            }),
        ],
      ),
    );
  }
}

class CoachHomeSessionList extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<dynamic> sessions;
  final bool isDark;
  final String emptyMessage;

  const CoachHomeSessionList({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.sessions,
    required this.isDark,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoachHomeSectionTitle(
            title: title,
            icon: icon,
            iconColor: iconColor,
            trailing: sessions.isNotEmpty ? '${sessions.length}' : null,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            _emptyState(Icons.event_available_rounded, emptyMessage, isDark)
          else
            ...sessions.take(5).map((session) => _sessionTile(session, isDark)),
        ],
      ),
    );
  }

  Widget _sessionTile(dynamic session, bool isDark) {
    final clientName = ApiService.displayName(
      session['client'] is Map ? Map<dynamic, dynamic>.from(session['client'] as Map) : null,
      fallback: 'Client',
    );
    final dateStr = session['date']?.toString() ?? session['dateTime']?.toString() ?? session['datetime']?.toString();
    final date = (dateStr != null && dateStr.isNotEmpty) ? DateTime.tryParse(dateStr) : null;
    final time = date != null
        ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : 'TBD';
    final duration = session['durationMinutes'] ?? 60;
    final status = session['status'] ?? 'pending';
    final statusColor = status == 'confirmed' || status == 'completed'
        ? CoachDashboardTheme.success
        : CoachDashboardTheme.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark ? const Color(0xFF1F2330) : const Color(0xFFF9FAFB),
        border: Border.all(color: isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(time, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: statusColor)),
                Text('$duration m', style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : CoachDashboardTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status.toString(),
                    style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CoachHomeActivityList extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  final bool isDark;

  const CoachHomeActivityList({
    super.key,
    required this.activities,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoachHomeSectionTitle(
            title: 'Recent Client Activity',
            icon: Icons.history_rounded,
            iconColor: CoachDashboardTheme.pink,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            _emptyState(Icons.directions_run_rounded, 'No recent client activity', isDark)
          else
            ...activities.take(5).map((a) {
              final clientName = a['clientName'];
              final activityType = a['activityType'];
              final duration = a['durationMinutes'];
              final status = a['status'] ?? 'approved';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDark ? const Color(0xFF252536) : const Color(0xFFF8F9FC),
                ),
                child: Row(
                  children: [
                    Icon(
                      status == 'approved' ? Icons.check_circle_rounded : Icons.pending_rounded,
                      size: 20,
                      color: status == 'approved' ? CoachDashboardTheme.success : CoachDashboardTheme.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$clientName · $activityType', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('$duration min', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

Widget _emptyState(IconData icon, String message, bool isDark) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: isDark ? Colors.white24 : CoachDashboardTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}