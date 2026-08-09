import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../services/api_service.dart';
import '../../../widgets/profile_avatar.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';

/// Full coach manage sheet for a 1-on-1 Session (Session API — not Appointments).
Future<bool> showCoachSessionDetailSheet({
  required BuildContext context,
  required Map<String, dynamic> session,
  required Future<void> Function() onChanged,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CoachSessionDetailSheet(
      session: session,
      onChanged: onChanged,
    ),
  );
  return result == true;
}

class _CoachSessionDetailSheet extends StatefulWidget {
  const _CoachSessionDetailSheet({
    required this.session,
    required this.onChanged,
  });

  final Map<String, dynamic> session;
  final Future<void> Function() onChanged;

  @override
  State<_CoachSessionDetailSheet> createState() => _CoachSessionDetailSheetState();
}

class _CoachSessionDetailSheetState extends State<_CoachSessionDetailSheet> {
  final ApiService _api = ApiService();
  late Map<String, dynamic> _session;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _coachNotesCtrl;
  late final TextEditingController _linkCtrl;
  late String _sessionMode;
  late int _duration;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _session = Map<String, dynamic>.from(widget.session);
    _notesCtrl = TextEditingController(text: _session['notes']?.toString() ?? '');
    _coachNotesCtrl = TextEditingController(text: _session['coachNotes']?.toString() ?? '');
    _linkCtrl = TextEditingController(text: _session['meetingLink']?.toString() ?? '');
    _sessionMode = _session['sessionMode']?.toString() == 'online' ? 'online' : 'in_person';
    final raw = _session['durationMinutes'] ?? 60;
    _duration = raw is num ? raw.toInt() : int.tryParse(raw.toString()) ?? 60;
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _coachNotesCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  String get _id => _session['_id'].toString();
  String get _status => _session['status']?.toString() ?? 'pending';
  bool get _closed => ['completed', 'cancelled', 'no_show'].contains(_status);
  bool get _startReached {
    final d = DateTime.tryParse(_session['date']?.toString() ?? '');
    if (d == null) return false;
    return !DateTime.now().toUtc().isBefore(d.toUtc());
  }

  String _clientName() {
    final client = _session['client'];
    if (client is Map) {
      return ApiService.displayName(Map<dynamic, dynamic>.from(client), fallback: 'Client');
    }
    return 'Client';
  }

  String? _clientPhoto() {
    final client = _session['client'];
    if (client is! Map) return null;
    final photo = (client['avatar'] ?? client['photoUrl'])?.toString().trim() ?? '';
    return photo.isEmpty ? null : photo;
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

  Future<void> _run(
    Future<Map<String, dynamic>> Function() action, {
    required String success,
    bool close = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await action();
      setState(() {
        _session = Map<String, dynamic>.from(updated);
        _changed = true;
        _busy = false;
        _notesCtrl.text = _session['notes']?.toString() ?? _notesCtrl.text;
        _coachNotesCtrl.text = _session['coachNotes']?.toString() ?? _coachNotesCtrl.text;
        _linkCtrl.text = _session['meetingLink']?.toString() ?? _linkCtrl.text;
        _sessionMode = _session['sessionMode']?.toString() == 'online' ? 'online' : 'in_person';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), backgroundColor: CoachDashboardTheme.success),
      );
      // Parent list refresh in background — don't hold the action spinner.
      widget.onChanged();
      if (close) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.friendlyError(e)),
            backgroundColor: CoachDashboardTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  Future<DateTime?> _pickDateTime({DateTime? initial}) async {
    final base = initial ?? DateTime.now().add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: base.isBefore(DateTime.now()) ? DateTime.now() : base,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Widget _meta(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _statusColor(_status);
    final attachments = (_session['attachments'] as List?) ?? const [];
    final link = _session['meetingLink']?.toString().trim() ?? '';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _changed && result != true) {
          // Caller already refreshed via onChanged during actions.
        }
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    ProfileAvatar(name: _clientName(), photoUrl: _clientPhoto(), radius: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_clientName(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _statusLabel(_status),
                              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_busy)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _meta('Date & time', _formatWhen(_session['date'])),
                _meta('Duration', '$_duration min'),
                _meta('Type', _sessionMode == 'online' ? 'Online' : 'In Person'),
                if (link.isNotEmpty) ...[
                  _meta('Meeting link', link),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy link'),
                  ),
                ],
                if (attachments.isNotEmpty) ...[
                  const Text('Attachments', style: TextStyle(fontWeight: FontWeight.w700)),
                  ...attachments.map((raw) {
                    final a = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
                    return Text('• ${a['name'] ?? 'Attachment'}', style: const TextStyle(fontSize: 13));
                  }),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _sessionMode,
                  decoration: const InputDecoration(labelText: 'Session type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'in_person', child: Text('In Person')),
                    DropdownMenuItem(value: 'online', child: Text('Online')),
                  ],
                  onChanged: _closed || _busy
                      ? null
                      : (v) => setState(() => _sessionMode = v ?? 'in_person'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: [30, 45, 60, 90].contains(_duration) ? _duration : 60,
                  decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()),
                  items: const [30, 45, 60, 90]
                      .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                      .toList(),
                  onChanged: _closed || _busy
                      ? null
                      : (v) => setState(() => _duration = v ?? 60),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _linkCtrl,
                  enabled: !_closed && !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Meeting link',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesCtrl,
                  enabled: !_closed && !_busy,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Session goal',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _coachNotesCtrl,
                  enabled: !_busy,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Coaching notes',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_status == 'pending')
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => _api.confirmSession(
                                    _id,
                                    coachNotes: _coachNotesCtrl.text.trim(),
                                    sessionMode: _sessionMode,
                                    meetingLink: _linkCtrl.text.trim(),
                                  ),
                                  success: 'Session confirmed',
                                ),
                        child: const Text('Confirm'),
                      ),
                    if (['confirmed', 'rescheduled'].contains(_status))
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : (!_startReached
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Cannot start before the scheduled session time.',
                                        ),
                                      ),
                                    );
                                  }
                                : () => _run(
                                      () => _api.startSession(
                                        _id,
                                        sessionMode: _sessionMode,
                                        meetingLink: _linkCtrl.text.trim().isEmpty
                                            ? null
                                            : _linkCtrl.text.trim(),
                                      ),
                                      success: 'Session in progress',
                                    )),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(_sessionMode == 'online' ? 'Start online' : 'Mark in progress'),
                      ),
                    if (['confirmed', 'rescheduled', 'in_progress'].contains(_status))
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : (!_startReached
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Cannot complete before the scheduled session time.',
                                        ),
                                      ),
                                    );
                                  }
                                : () => _run(
                                      () => _api.completeSession(
                                        _id,
                                        coachNotes: _coachNotesCtrl.text.trim(),
                                      ),
                                      success: 'Session completed',
                                    )),
                        child: Text(_startReached ? 'Mark completed' : 'Complete after start time'),
                      ),
                    if (!_closed) ...[
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                final when = await _pickDateTime(
                                  initial: DateTime.tryParse(_session['date']?.toString() ?? ''),
                                );
                                if (when == null) return;
                                await _run(
                                  () => _api.rescheduleSession(
                                    _id,
                                    when.toUtc().toIso8601String(),
                                    coachNotes: _coachNotesCtrl.text.trim(),
                                  ),
                                  success: 'Session rescheduled',
                                );
                              },
                        child: const Text('Reschedule'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => _api.updateSession(_id, {
                                    'durationMinutes': _duration,
                                    'notes': _notesCtrl.text.trim(),
                                    'coachNotes': _coachNotesCtrl.text.trim(),
                                    'sessionMode': _sessionMode,
                                    'meetingLink': _linkCtrl.text.trim(),
                                  }),
                                  success: 'Session details saved',
                                ),
                        child: const Text('Save details'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => _api.updateSessionMeetingLink(
                                    _id,
                                    meetingLink: _linkCtrl.text.trim(),
                                    sessionMode: _sessionMode,
                                  ),
                                  success: 'Meeting link saved',
                                ),
                        child: const Text('Save link / type'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => _api.updateSessionNotes(
                                    _id,
                                    coachNotes: _coachNotesCtrl.text.trim(),
                                    notes: _notesCtrl.text.trim(),
                                  ),
                                  success: 'Notes saved',
                                ),
                        child: const Text('Save notes'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                final nameCtrl = TextEditingController(text: 'Session note');
                                final urlCtrl = TextEditingController();
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (dCtx) => AlertDialog(
                                    title: const Text('Add attachment'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: nameCtrl,
                                          decoration: const InputDecoration(labelText: 'Name'),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: urlCtrl,
                                          decoration: const InputDecoration(
                                            labelText: 'Image URL or data URL',
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dCtx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(dCtx, true),
                                        child: const Text('Upload'),
                                      ),
                                    ],
                                  ),
                                );
                                final file = urlCtrl.text.trim();
                                final name = nameCtrl.text.trim();
                                nameCtrl.dispose();
                                urlCtrl.dispose();
                                if (ok != true || file.isEmpty) return;
                                await _run(
                                  () => _api.addSessionAttachment(_id, file: file, name: name),
                                  success: 'Attachment added',
                                );
                              },
                        child: const Text('Add attachment'),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: CoachDashboardTheme.danger),
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => _api.cancelSession(_id, coachNotes: _coachNotesCtrl.text.trim()),
                                  success: 'Session cancelled',
                                  close: true,
                                ),
                        child: const Text('Cancel session'),
                      ),
                    ],
                    if (['completed', 'in_progress', 'confirmed', 'rescheduled'].contains(_status))
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                final when = await _pickDateTime(
                                  initial: DateTime.now().add(const Duration(days: 7)),
                                );
                                if (when == null) return;
                                await _run(
                                  () => _api.createFollowUpSession(_id, {
                                    'date': when.toUtc().toIso8601String(),
                                    'durationMinutes': _duration,
                                    'sessionMode': _sessionMode,
                                    if (_sessionMode == 'online')
                                      'meetingLink': _linkCtrl.text.trim(),
                                    'notes': 'Follow-up session',
                                    'coachNotes': _coachNotesCtrl.text.trim(),
                                  }),
                                  success: 'Follow-up scheduled',
                                );
                              },
                        child: const Text('Schedule follow-up'),
                      ),
                    if (['cancelled', 'completed', 'no_show'].contains(_status))
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: CoachDashboardTheme.danger),
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => _api.deleteSession(_id),
                                  success: 'Session removed',
                                  close: true,
                                ),
                        child: const Text('Delete'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
