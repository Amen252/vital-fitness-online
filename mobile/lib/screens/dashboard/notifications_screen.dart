import 'package:flutter/material.dart';
import 'widgets/coach_home/coach_dashboard_theme.dart';
import '../../../services/api_service.dart';
import '../../../utils/date_utils.dart';
import '../../../widgets/animations/animations.dart';

class NotificationsScreen extends StatefulWidget {
  final void Function({DateTime? weekStart})? onOpenCoachSchedule;

  const NotificationsScreen({super.key, this.onOpenCoachSchedule});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isRefreshing = false;
  List<dynamic> _notifications = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() => _isRefreshing = true);
    }
    try {
      final notifs = await _apiService.getUserNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifs;
          _errorMessage = null;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          if (!isRefresh) {
            _errorMessage = ApiService.friendlyError(e);
          }
        });
        if (isRefresh) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ApiService.friendlyError(e)),
              backgroundColor: CoachDashboardTheme.danger,
            ),
          );
        }
      }
    }
  }

  bool _isScheduleNotification(Map<String, dynamic> n) {
    final type = n['type']?.toString() ?? '';
    if (type == 'workout') return true;
    final data = n['data'] as Map<String, dynamic>?;
    if (data?['screen'] == 'schedule') return true;
    final msg = n['message']?.toString().toLowerCase() ?? '';
    return msg.contains('workout plan')
        || msg.contains('workout schedule')
        || msg.contains('weekly workout')
        || msg.contains('workout scheduled');
  }

  DateTime? _weekStartFromNotification(Map<String, dynamic> n) {
    final data = n['data'] as Map<String, dynamic>?;
    if (data != null) {
      if (data['weekStart'] != null) {
        return parseApiDateOnly(data['weekStart'].toString());
      }
      if (data['startDateTime'] != null) {
        final dt = parseApiDateTime(data['startDateTime'].toString());
        if (dt != null) return mondayOf(dt);
      }
    }
    final msg = n['message']?.toString() ?? '';
    final match = RegExp(r'starting\s+(\d{1,2}/\d{1,2}/\d{4})', caseSensitive: false).firstMatch(msg);
    if (match != null) {
      final parts = match.group(1)!.split('/');
      final month = int.tryParse(parts[0]);
      final day = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (month != null && day != null && year != null) {
        return mondayOf(DateTime(year, month, day));
      }
    }
    return null;
  }

  Future<void> _onNotificationTap(Map<String, dynamic> n) async {
    final id = n['_id']?.toString();
    if (id != null) {
      await _apiService.markUserNotificationRead(id);
      await _fetchNotifications(isRefresh: true);
    }

    if (!_isScheduleNotification(n)) return;

    final weekStart = _weekStartFromNotification(n);
    if (widget.onOpenCoachSchedule != null) {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onOpenCoachSchedule!(weekStart: weekStart);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Open Schedule from the menu to view your coach\'s plan')),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'workout':
        return Icons.fitness_center_rounded;
      case 'class':
        return Icons.event_rounded;
      case 'coach':
        return Icons.chat_bubble_rounded;
      case 'diet':
        return Icons.restaurant_menu_rounded;
      case 'reminder':
        return Icons.alarm_rounded;
      case 'update':
        return Icons.update_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'workout':
        return const Color(0xFFFF6B6B);
      case 'class':
        return const Color(0xFF00D4AA);
      case 'coach':
        return CoachDashboardTheme.primary;
      case 'diet':
        return const Color(0xFF10B981);
      case 'reminder':
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  String _notificationTitle(Map<String, dynamic> n) {
    if (n['title'] != null) return n['title'].toString();
    switch (n['type']?.toString()) {
      case 'diet':
        return 'Diet Plan';
      case 'reminder':
        return 'Meal Reminder';
      case 'workout':
        return 'Coach Schedule';
      case 'update':
        return 'Update';
      default:
        return 'Notification';
    }
  }

  String _notificationBody(Map<String, dynamic> n) {
    return n['body']?.toString() ?? n['message']?.toString() ?? '';
  }

  String _notificationDate(Map<String, dynamic> n) {
    return n['date']?.toString() ?? n['createdAt']?.toString() ?? '';
  }

  String _formatTime(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      appBar: CoachDashboardTheme.coachAppBar(
        context: context,
        title: 'Notifications',
        leading: Hero(
          tag: 'user_notification_bell',
          child: Material(
            color: Colors.transparent,
            child: IconButton(
              icon: const Icon(Icons.notifications_rounded, color: Colors.white),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: (_isLoading || _isRefreshing) ? null : () => _fetchNotifications(isRefresh: true),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const LottieLoadingCenter()
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: CoachDashboardTheme.danger),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => _fetchNotifications(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : PremiumRefreshIndicator(
              onRefresh: () => _fetchNotifications(isRefresh: true),
              child: _notifications.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.6,
                          child: Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.notifications_off_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                              const SizedBox(height: 16),
                              const Text('No new notifications', style: TextStyle(color: Colors.grey, fontSize: 16)),
                            ]),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (ctx, i) {
                    final n = Map<String, dynamic>.from(_notifications[i] as Map);
                    final color = _getColorForType(n['type'] as String? ?? '');
                    final isSchedule = _isScheduleNotification(n);
                    return Container(
                      key: ValueKey(n['_id']),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF181B24) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: ListTile(
                        onTap: () => _onNotificationTap(n),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                          child: Icon(_getIconForType(n['type'] as String? ?? ''), color: color, size: 20),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_notificationTitle(n), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(_formatTime(_notificationDate(n)), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_notificationBody(n), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              if (isSchedule) ...[
                                const SizedBox(height: 6),
                                const Text(
                                  'Tap to view coach schedule',
                                  style: TextStyle(fontSize: 12, color: CoachDashboardTheme.primary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ),
                        trailing: isSchedule ? const Icon(Icons.chevron_right, color: CoachDashboardTheme.primary) : null,
                      ),
                    )
                        .staggerIn(i);
                  },
                ),
            ),
    );
  }
}
