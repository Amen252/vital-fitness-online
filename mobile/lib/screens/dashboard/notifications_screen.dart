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

  bool _isMealReminder(Map<String, dynamic> n) {
    final data = n['data'];
    if (data is Map && data['kind']?.toString() == 'meal_reminder') return true;
    final type = n['type']?.toString() ?? '';
    final msg = n['message']?.toString().toLowerCase() ?? '';
    return type == 'reminder' && msg.contains('meal reminder');
  }

  Map<String, dynamic>? _mealReminderData(Map<String, dynamic> n) {
    final data = n['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
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

    if (_isMealReminder(n)) {
      if (!mounted) return;
      await _showMealReminderSheet(n);
      return;
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

  Future<void> _showMealReminderSheet(Map<String, dynamic> n) async {
    final data = _mealReminderData(n) ?? <String, dynamic>{};
    final mealName = (data['mealName'] ?? data['mealLabel'] ?? 'Meal').toString();
    final mealType = data['mealType']?.toString();
    final time = data['reminderTime']?.toString() ?? '';
    final foodItems = (data['foodItems'] as List<dynamic>? ?? [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final description = data['description']?.toString().trim() ?? '';
    final food = foodItems.isNotEmpty
        ? foodItems.join(', ')
        : description;
    final calories = (data['calories'] as num?)?.toInt() ?? 0;
    final protein = (data['protein'] as num?)?.toInt() ?? 0;
    final carbs = (data['carbs'] as num?)?.toInt() ?? 0;
    final fats = (data['fats'] as num?)?.toInt() ?? 0;
    final portion = data['portionSize']?.toString().trim() ?? '';
    final notes = [
      data['prepInstructions']?.toString().trim() ?? '',
      data['mealNotes']?.toString().trim() ?? '',
    ].where((s) => s.isNotEmpty).join('\n');
    final nutrition = <String>[
      if (calories > 0) '$calories kcal',
      if (protein > 0) 'P ${protein}g',
      if (carbs > 0) 'C ${carbs}g',
      if (fats > 0) 'F ${fats}g',
    ].join(' · ');

    var completing = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black26,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Meal Reminder', style: CoachDashboardTheme.sectionTitle(isDark)),
                    const SizedBox(height: 12),
                    Text(mealName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    if (time.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Scheduled at $time', style: CoachDashboardTheme.bodyMuted(isDark)),
                    ],
                    if (food.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text('Food items', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black87)),
                      const SizedBox(height: 4),
                      Text(food),
                    ],
                    if (portion.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Portion: $portion'),
                    ],
                    if (nutrition.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Nutrition: $nutrition'),
                    ],
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Coach notes', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black87)),
                      const SizedBox(height: 4),
                      Text(notes),
                    ],
                    if (food.isEmpty && nutrition.isEmpty && n['message'] != null) ...[
                      const SizedBox(height: 12),
                      Text(n['message'].toString()),
                    ],
                    const SizedBox(height: 20),
                    if (mealType != null && mealType.isNotEmpty)
                      ElevatedButton.icon(
                        style: CoachDashboardTheme.primaryButtonStyle(),
                        onPressed: completing
                            ? null
                            : () async {
                                setSheetState(() => completing = true);
                                try {
                                  await _apiService.logDietAdherence({
                                    'mealType': mealType,
                                    'followed': true,
                                  });
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Meal marked complete. Progress updated.'),
                                      backgroundColor: CoachDashboardTheme.success,
                                    ),
                                  );
                                } catch (e) {
                                  setSheetState(() => completing = false);
                                  if (!ctx.mounted) return;
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(ApiService.friendlyError(e)),
                                      backgroundColor: CoachDashboardTheme.danger,
                                    ),
                                  );
                                }
                              },
                        icon: completing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(completing ? 'Saving…' : 'Mark meal completed'),
                      ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
                    final isMealReminder = _isMealReminder(n);
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
                              Text(_notificationBody(n), style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 4, overflow: TextOverflow.ellipsis),
                              if (isMealReminder) ...[
                                const SizedBox(height: 6),
                                const Text(
                                  'Tap to view meal details',
                                  style: TextStyle(fontSize: 12, color: CoachDashboardTheme.primary, fontWeight: FontWeight.w600),
                                ),
                              ] else if (isSchedule) ...[
                                const SizedBox(height: 6),
                                const Text(
                                  'Tap to view coach schedule',
                                  style: TextStyle(fontSize: 12, color: CoachDashboardTheme.primary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ),
                        trailing: (isSchedule || isMealReminder)
                            ? const Icon(Icons.chevron_right, color: CoachDashboardTheme.primary)
                            : null,
                      ),
                    )
                        .staggerIn(i);
                  },
                ),
            ),
    );
  }
}
