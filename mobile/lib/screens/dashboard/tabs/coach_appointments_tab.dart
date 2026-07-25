import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/api_service.dart';
import '../../../widgets/scrollable_body.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';

class CoachAppointmentsTab extends StatefulWidget {
  const CoachAppointmentsTab({super.key});

  @override
  State<CoachAppointmentsTab> createState() => _CoachAppointmentsTabState();
}

class _CoachAppointmentsTabState extends State<CoachAppointmentsTab> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appts = await _api.getCoachAppointments();
      if (!mounted) return;
      setState(() {
        _appointments = appts.map((a) => Map<String, dynamic>.from(a as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiService.friendlyError(e);
          _loading = false;
        });
      }
    }
  }

  String _formatDateTime(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return '—';
    return DateFormat('EEE, MMM d · h:mm a').format(d.toLocal());
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return CoachDashboardTheme.success;
      case 'rejected':
      case 'cancelled':
        return CoachDashboardTheme.danger;
      case 'rescheduled':
        return CoachDashboardTheme.warning;
      case 'completed':
        return CoachDashboardTheme.primary;
      default:
        return CoachDashboardTheme.accent;
    }
  }

  List<Map<String, dynamic>> get _pending =>
      _appointments.where((a) => ['pending', 'rescheduled'].contains(a['status']?.toString())).toList();

  List<Map<String, dynamic>> get _upcoming {
    final now = DateTime.now();
    return _appointments.where((a) {
      final d = DateTime.tryParse(a['dateTime']?.toString() ?? '');
      final status = a['status']?.toString() ?? '';
      return d != null && d.isAfter(now) && status == 'approved';
    }).toList();
  }

  Future<void> _approve(Map<String, dynamic> appt) async {
    try {
      await _api.approveAppointment(appt['_id'].toString());
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment approved.'), backgroundColor: CoachDashboardTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: CoachDashboardTheme.danger),
        );
      }
    }
  }

  Future<void> _reject(Map<String, dynamic> appt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline appointment?'),
        content: Text('Decline the request from ${_clientName(appt)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CoachDashboardTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.rejectAppointment(appt['_id'].toString());
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment declined.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: CoachDashboardTheme.danger),
        );
      }
    }
  }

  String _clientName(Map<String, dynamic> appt) {
    final client = appt['client'];
    if (client is Map) {
      return ApiService.displayName(Map<dynamic, dynamic>.from(client), fallback: 'Member');
    }
    return 'Member';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CoachPage(
      title: 'Appointments',
      actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      body: _loading
          ? const ScrollableCenter(child: CircularProgressIndicator(color: CoachDashboardTheme.primary))
          : _error != null
              ? ScrollableCenter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: CoachDashboardTheme.danger)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: CoachDashboardTheme.primary,
                  onRefresh: _load,
                  child: ScrollableBody(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _section('Pending Requests', _pending, isDark, showActions: true),
                        const SizedBox(height: 20),
                        _section('Upcoming', _upcoming, isDark, showActions: false),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _section(String title, List<Map<String, dynamic>> items, bool isDark, {required bool showActions}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Text(
            title == 'Pending Requests' ? 'No pending appointment requests.' : 'No upcoming appointments.',
            style: TextStyle(color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
          )
        else
          ...items.map((a) => _card(a, isDark, showActions: showActions)),
      ],
    );
  }

  Widget _card(Map<String, dynamic> appt, bool isDark, {required bool showActions}) {
    final status = appt['status']?.toString() ?? 'pending';
    final color = _statusColor(status);
    final notes = appt['notes']?.toString().trim() ?? '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.event_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_clientName(appt), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(_formatDateTime(appt['dateTime']), style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  status[0].toUpperCase() + status.substring(1),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Member note: $notes', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : CoachDashboardTheme.textSecondary)),
          ],
          if (showActions) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reject(appt),
                    style: OutlinedButton.styleFrom(foregroundColor: CoachDashboardTheme.danger),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: CoachDashboardTheme.primaryButtonStyle(),
                    onPressed: () => _approve(appt),
                    child: const Text('Approve', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
