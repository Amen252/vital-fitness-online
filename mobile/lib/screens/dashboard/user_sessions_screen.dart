import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/scrollable_body.dart';
import 'widgets/coach_home/coach_dashboard_theme.dart';
import '../../widgets/silent_refresh.dart';

/// Member view of coach-created 1-on-1 Sessions (Session collection — not Appointments).
class UserSessionsScreen extends StatefulWidget {
  const UserSessionsScreen({super.key});

  @override
  State<UserSessionsScreen> createState() => _UserSessionsScreenState();
}

class _UserSessionsScreenState extends State<UserSessionsScreen>
    with WidgetsBindingObserver {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = await _api.getSessions();
      if (!mounted) return;
      setState(() {
        _sessions = rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiService.friendlyError(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatWhen(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return '—';
    return DateFormat('EEE, MMM d · h:mm a').format(d.toLocal());
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'in_progress':
        return 'In Progress';
      case 'pending':
        return 'Pending';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'rescheduled':
        return 'Rescheduled';
      case 'no_show':
        return 'Missed';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return CoachDashboardTheme.success;
      case 'in_progress':
        return const Color(0xFF0EA5E9);
      case 'pending':
      case 'rescheduled':
        return CoachDashboardTheme.warning;
      case 'completed':
        return CoachDashboardTheme.primary;
      case 'cancelled':
      case 'no_show':
        return CoachDashboardTheme.danger;
      default:
        return CoachDashboardTheme.accent;
    }
  }

  String _coachName(Map<String, dynamic> s) {
    final coach = s['coach'];
    if (coach is Map) {
      return ApiService.displayName(Map<dynamic, dynamic>.from(coach), fallback: 'Your coach');
    }
    return 'Your coach';
  }

  String? _coachPhoto(Map<String, dynamic> s) {
    final coach = s['coach'];
    if (coach is! Map) return null;
    final photo = (coach['avatar'] ?? coach['photoUrl'])?.toString().trim() ?? '';
    return photo.isEmpty ? null : photo;
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<Map<String, dynamic>> get _upcoming {
    final now = DateTime.now();
    return _sessions.where((s) {
      final status = s['status']?.toString() ?? '';
      if (['completed', 'cancelled', 'no_show'].contains(status)) return false;
      if (status == 'in_progress') return true;
      final d = DateTime.tryParse(s['date']?.toString() ?? '');
      return d != null && d.isAfter(now.subtract(const Duration(hours: 1)));
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? now;
        final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? now;
        return da.compareTo(db);
      });
  }

  List<Map<String, dynamic>> get _history {
    final ids = _upcoming.map((s) => s['_id']?.toString()).toSet();
    return _sessions.where((s) => !ids.contains(s['_id']?.toString())).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(0);
        final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(0);
        return db.compareTo(da);
      });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      appBar: AppBar(
        title: const Text('1-on-1 Sessions'),
        backgroundColor: CoachDashboardTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: CoachDashboardTheme.danger)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : SilentRefreshIndicator(
                  color: CoachDashboardTheme.primary,
                  onRefresh: () => _load(),
                  child: ScrollableBody(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _section('Upcoming', _upcoming, isDark),
                        const SizedBox(height: 20),
                        _section('History', _history, isDark),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _section(String title, List<Map<String, dynamic>> items, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: CoachDashboardTheme.cardDecoration(isDark),
            child: Column(
              children: [
                Icon(
                  title == 'Upcoming' ? Icons.event_available_outlined : Icons.history_rounded,
                  size: 40,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
                const SizedBox(height: 10),
                Text(
                  title == 'Upcoming' ? 'No upcoming 1-on-1 sessions' : 'No session history yet',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  title == 'Upcoming'
                      ? 'When your coach schedules a session for you, it appears here automatically.'
                      : 'Completed and past sessions appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ...items.map((s) => _card(s, isDark)),
      ],
    );
  }

  Widget _card(Map<String, dynamic> s, bool isDark) {
    final status = s['status']?.toString() ?? 'pending';
    final color = _statusColor(status);
    final coachName = _coachName(s);
    final photo = _coachPhoto(s);
    final duration = s['durationMinutes'] ?? 60;
    final mode = s['sessionMode']?.toString() == 'online' ? 'Online' : 'In Person';
    final notes = s['notes']?.toString().trim() ?? '';
    final coachNotes = s['coachNotes']?.toString().trim() ?? '';
    final link = s['meetingLink']?.toString().trim() ?? '';
    final canJoin = link.isNotEmpty &&
        ['confirmed', 'rescheduled', 'in_progress'].contains(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(name: coachName, photoUrl: photo, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(coachName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(_formatWhen(s['date']), style: const TextStyle(fontSize: 13)),
                    Text(
                      '$duration min · $mode',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Goal: $notes', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : CoachDashboardTheme.textSecondary)),
          ],
          if (status == 'completed' && coachNotes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Coach notes: $coachNotes', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? Colors.white60 : CoachDashboardTheme.textSecondary)),
          ],
          if (canJoin) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openLink(link),
                icon: const Icon(Icons.videocam_rounded),
                label: const Text('Join online session'),
                style: FilledButton.styleFrom(
                  backgroundColor: CoachDashboardTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
