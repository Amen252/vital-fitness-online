import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../widgets/scrollable_body.dart';
import '../../widgets/coach_appointment_days_display.dart';
import 'widgets/coach_home/coach_dashboard_theme.dart';
import '../../widgets/silent_refresh.dart';

/// Members book appointments only on the coach's selected appointment days,
/// using per-day hours from the coach profile. Non-working days are disabled.
class UserAppointmentsScreen extends StatefulWidget {
  const UserAppointmentsScreen({super.key});

  @override
  State<UserAppointmentsScreen> createState() => _UserAppointmentsScreenState();
}

class _UserAppointmentsScreenState extends State<UserAppointmentsScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;

  String? _coachId;
  String _coachName = 'your coach';
  Map<String, dynamic>? _coachProfile;
  Set<String> _appointmentDays = {};

  List<Map<String, dynamic>> _appointments = [];

  DateTime? _selectedDate;
  bool _slotsLoading = false;
  List<Map<String, dynamic>> _slots = [];
  String? _selectedTime;
  bool _booking = false;
  int _availabilityRequestSeq = 0;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  static const _englishWeekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _weekday(DateTime d) => _englishWeekdays[d.weekday - 1];

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  List<DateTime> get _next21Days {
    final today = _dateOnly(DateTime.now());
    return List.generate(21, (i) => today.add(Duration(days: i)));
  }

  bool _isAppointmentDay(DateTime d) => _appointmentDays.contains(_weekday(d));

  List<String> get _sortedAppointmentDays {
    const order = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final days = _appointmentDays.toList()
      ..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    return days;
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    String? coachId;
    var days = <String>{};
    try {
      final coaching = await _api.getUserCoaching();
      final appts = await _api.getUserAppointments();

      String coachName = 'your coach';
      days = <String>{};

      if (coaching != null && coaching['coach'] != null) {
        final coach = Map<String, dynamic>.from(coaching['coach'] as Map);
        coachId = coach['_id']?.toString();
        coachName = coach['name']?.toString() ?? coachName;
        final profile = coach['profile'];
        if (profile is Map) {
          final appointmentDays = profile['appointmentDays'];
          if (appointmentDays is List && appointmentDays.isNotEmpty) {
            for (final d in appointmentDays) {
              days.add(d.toString());
            }
          } else if (profile['workingDays'] is List) {
            for (final d in (profile['workingDays'] as List)) {
              days.add(d.toString());
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _coachId = coachId;
        _coachName = coachName;
        _coachProfile = coaching != null && coaching['coach'] != null ? Map<String, dynamic>.from((coaching['coach'] as Map)['profile'] ?? {}) : null;
        _appointmentDays = days;
        _appointments = appts.map((a) => Map<String, dynamic>.from(a as Map)).toList();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiService.friendlyError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    // Auto-select the first appointment day that still has bookable times.
    if (mounted && coachId != null && days.isNotEmpty) {
      await _autoSelectFirstBookableDay();
    }
  }

  bool _slotIsBooked(Map<String, dynamic> slot) {
    final booked = slot['booked'];
    return booked == true || booked == 1;
  }

  bool _slotIsPast(Map<String, dynamic> slot) {
    final past = slot['past'];
    return past == true || past == 1;
  }

  List<Map<String, dynamic>> _parseSlots(List<dynamic>? raw) {
    return (raw ?? []).map((s) => Map<String, dynamic>.from(s as Map)).toList();
  }

  bool _slotIsAvailable(Map<String, dynamic> slot) {
    final value = slot['available'];
    return value == true || value == 1;
  }

  Future<bool> _loadSlotsForDate(DateTime date) async {
    if (!_isAppointmentDay(date) || _coachId == null) return false;

    final requestSeq = ++_availabilityRequestSeq;

    setState(() {
      _selectedDate = _dateOnly(date);
      _selectedTime = null;
      _slots = [];
      _slotsLoading = true;
    });

    try {
      final data = await _api.getCoachAvailability(_coachId!, _ymd(date));
      if (!mounted || requestSeq != _availabilityRequestSeq) return false;

      if (data['isWorkingDay'] == false) {
        setState(() {
          _slots = [];
        });
        return false;
      }

      if (data['appointmentDays'] is List && (data['appointmentDays'] as List).isNotEmpty) {
        _appointmentDays = (data['appointmentDays'] as List).map((d) => d.toString()).toSet();
      } else if (data['workingDays'] is List) {
        _appointmentDays = (data['workingDays'] as List).map((d) => d.toString()).toSet();
      }

      final allSlots = _parseSlots(data['slots'] as List?);
      setState(() {
        _slots = allSlots;
      });
      return allSlots.any(_slotIsAvailable);
    } catch (e) {
      if (mounted && requestSeq == _availabilityRequestSeq) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: CoachDashboardTheme.danger),
        );
      }
      return false;
    } finally {
      if (mounted && requestSeq == _availabilityRequestSeq) {
        setState(() => _slotsLoading = false);
      }
    }
  }

  Future<void> _autoSelectFirstBookableDay() async {
    for (final date in _next21Days) {
      if (!_isAppointmentDay(date)) continue;
      final hasSlots = await _loadSlotsForDate(date);
      if (!mounted) return;
      if (hasSlots) return;
    }
  }

  Future<void> _selectDate(DateTime date) async {
    await _loadSlotsForDate(date);
  }

  Future<void> _book() async {
    if (_coachId == null || _selectedDate == null || _selectedTime == null) return;
    setState(() => _booking = true);
    try {
      await _api.bookAppointment(
        coachId: _coachId!,
        date: _ymd(_selectedDate!),
        time: _selectedTime!,
        notes: _notesController.text.trim(),
      );
      if (!mounted) return;
      _notesController.clear();
      setState(() => _booking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment requested! Your coach will confirm it.'), backgroundColor: CoachDashboardTheme.success),
      );
      final keepDate = _selectedDate!;
      // Refresh lists in background so Book spinner stops with the API.
      _refreshAppointments().then((_) {
        if (mounted) _selectDate(keepDate);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _booking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: CoachDashboardTheme.danger),
        );
      }
    } finally {
      if (mounted && _booking) setState(() => _booking = false);
    }
  }

  Future<void> _refreshAppointments() async {
    try {
      final appts = await _api.getUserAppointments();
      if (mounted) {
        setState(() => _appointments = appts.map((a) => Map<String, dynamic>.from(a as Map)).toList());
      }
    } catch (_) {}
  }

  Future<void> _cancel(Map<String, dynamic> appt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: Text('Cancel your appointment on ${_formatDateTime(appt['dateTime'])}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CoachDashboardTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel it'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.cancelUserAppointment(appt['_id'].toString());
      await _refreshAppointments();
      if (_selectedDate != null) await _selectDate(_selectedDate!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment cancelled.')),
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

  String _formatDateTime(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return '—';
    return DateFormat('EEE, MMM d · h:mm a').format(d.toLocal());
  }

  String _formatSlot(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final dt = DateTime(2000, 1, 1, int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
    return DateFormat('h:mm a').format(dt);
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

  String _statusLabel(String status) {
    if (status.isEmpty) return 'Pending';
    return status[0].toUpperCase() + status.substring(1);
  }

  List<Map<String, dynamic>> get _upcoming {
    final now = DateTime.now();
    return _appointments.where((a) {
      final d = DateTime.tryParse(a['dateTime']?.toString() ?? '');
      final status = a['status']?.toString() ?? '';
      return d != null &&
          d.isAfter(now) &&
          ['pending', 'approved', 'rescheduled'].contains(status);
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a['dateTime']?.toString() ?? '') ?? now;
        final db = DateTime.tryParse(b['dateTime']?.toString() ?? '') ?? now;
        return da.compareTo(db);
      });
  }

  List<Map<String, dynamic>> get _history {
    final upcomingIds = _upcoming.map((a) => a['_id']).toSet();
    return _appointments.where((a) => !upcomingIds.contains(a['_id'])).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a['dateTime']?.toString() ?? '') ?? DateTime(0);
        final db = DateTime.tryParse(b['dateTime']?.toString() ?? '') ?? DateTime(0);
        return db.compareTo(da);
      });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      appBar: AppBar(
        title: const Text('Appointments'),
        backgroundColor: CoachDashboardTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _error != null
              ? _errorView()
              : SilentRefreshIndicator(
                  color: CoachDashboardTheme.primary,
                  onRefresh: _loadAll,
                  child: ScrollableBody(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _coachId == null
                          ? [_noCoachView(isDark)]
                          : [
                              _bookingCard(isDark),
                              const SizedBox(height: 24),
                              _appointmentsList('Upcoming', _upcoming, isDark, allowCancel: true),
                              const SizedBox(height: 20),
                              _appointmentsList('History', _history, isDark, allowCancel: false),
                              const SizedBox(height: 40),
                            ],
                    ),
                  ),
                ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: const TextStyle(color: CoachDashboardTheme.danger)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadAll, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _noCoachView(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        children: [
          Icon(Icons.event_busy_rounded, size: 48, color: isDark ? Colors.white24 : Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('No coach assigned', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'You need an assigned coach before you can book appointments. Request a coach from the Coaches tab.',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _bookingCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available_rounded, color: CoachDashboardTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Book with $_coachName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Only your coach\'s selected appointment days can be booked. Unavailable days are greyed out.',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
          ),
          if (_appointmentDays.isNotEmpty && _coachProfile != null) ...[
            const SizedBox(height: 12),
            CoachAppointmentDaysDisplay(
              appointmentDays: _appointmentDays.toList(),
              dayAvailability: _coachProfile?['dayAvailability'] as List?,
              appointmentDurationMinutes: _coachProfile?['appointmentDurationMinutes'] as int?,
              isDark: isDark,
            ),
          ],
          const SizedBox(height: 14),
          _sectionLabel('SELECT A DAY', isDark),
          const SizedBox(height: 8),
          SizedBox(height: 78, child: _dateStrip(isDark)),
          const SizedBox(height: 16),
          _sectionLabel('TIME SLOTS', isDark),
          const SizedBox(height: 8),
          _slotsArea(isDark),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Notes (optional)'),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: CoachDashboardTheme.primaryButtonStyle(),
              onPressed: (_selectedTime == null || _booking) ? null : _book,
              icon: const Icon(Icons.check_rounded, color: Colors.white),
              label: Text(
                _selectedTime == null
                    ? 'Select a time'
                    : 'Book ${_formatSlot(_selectedTime!)}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateStrip(bool isDark) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _next21Days.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        final date = _next21Days[i];
        final enabled = _isAppointmentDay(date);
        final selected = _selectedDate != null && _dateOnly(_selectedDate!) == date;
        final baseColor = selected
            ? CoachDashboardTheme.primary
            : (isDark ? const Color(0xFF181B24) : Colors.white);
        return Opacity(
          opacity: enabled ? 1 : 0.35,
          child: InkWell(
            onTap: enabled ? () => _selectDate(date) : null,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 58,
              decoration: BoxDecoration(
                color: enabled
                    ? baseColor
                    : (isDark ? const Color(0xFF12141A) : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? CoachDashboardTheme.primary
                      : (enabled
                          ? (isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB))
                          : (isDark ? const Color(0xFF1E2128) : const Color(0xFFE5E7EB))),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : (enabled
                              ? (isDark ? Colors.white60 : CoachDashboardTheme.textSecondary)
                              : (isDark ? Colors.white24 : Colors.grey)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d').format(date),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? Colors.white
                          : (enabled
                              ? (isDark ? Colors.white : CoachDashboardTheme.textPrimary)
                              : (isDark ? Colors.white24 : Colors.grey)),
                    ),
                  ),
                  Text(
                    enabled ? DateFormat('MMM').format(date) : 'Off',
                    style: TextStyle(
                      fontSize: 10,
                      color: selected
                          ? Colors.white70
                          : (enabled
                              ? (isDark ? Colors.white38 : CoachDashboardTheme.textSecondary)
                              : (isDark ? Colors.white24 : Colors.grey)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _slotsArea(bool isDark) {
    if (_selectedDate == null) {
      return Text('Select a day to see times.',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : CoachDashboardTheme.textSecondary));
    }
    if (!_isAppointmentDay(_selectedDate!)) {
      return Text('The coach does not accept appointments on this day.',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : CoachDashboardTheme.textSecondary));
    }
    if (_slots.isEmpty) {
      return Text(
        'No time slots for this day.',
        style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : CoachDashboardTheme.textSecondary),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _slots.map((slot) {
        final time = slot['time']?.toString() ?? '';
        final available = _slotIsAvailable(slot);
        final booked = _slotIsBooked(slot);
        final selected = _selectedTime == time;
        final label = booked
            ? '${_formatSlot(time)} · Reserved'
            : _slotIsPast(slot)
                ? '${_formatSlot(time)} · Past'
                : _formatSlot(time);
        return _SlotChip(
          label: label,
          available: available,
          selected: selected,
          isDark: isDark,
          onTap: available ? () => setState(() => _selectedTime = time) : null,
        );
      }).toList(),
    );
  }

  Widget _appointmentsList(String title, List<Map<String, dynamic>> items, bool isDark, {required bool allowCancel}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Text(
            title == 'Upcoming' ? 'No upcoming appointments.' : 'No past appointments.',
            style: TextStyle(color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
          )
        else
          ...items.map((a) => _appointmentCard(a, isDark, allowCancel: allowCancel)),
      ],
    );
  }

  Widget _appointmentCard(Map<String, dynamic> appt, bool isDark, {required bool allowCancel}) {
    final status = appt['status']?.toString() ?? 'pending';
    final color = _statusColor(status);
    final notes = appt['notes']?.toString().trim() ?? '';
    final coachNotes = appt['coachNotes']?.toString().trim() ?? '';
    final canCancel = allowCancel && ['pending', 'approved', 'rescheduled'].contains(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181B24) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.event_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_formatDateTime(appt['dateTime']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Text(_statusLabel(status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Your note: $notes', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : CoachDashboardTheme.textSecondary)),
          ],
          if (coachNotes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Coach: $coachNotes', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? Colors.white60 : CoachDashboardTheme.textSecondary)),
          ],
          if (canCancel) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _cancel(appt),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CoachDashboardTheme.danger,
                  side: const BorderSide(color: CoachDashboardTheme.danger),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: isDark ? Colors.white38 : CoachDashboardTheme.textSecondary,
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  final String label;
  final bool available;
  final bool selected;
  final bool isDark;
  final VoidCallback? onTap;

  const _SlotChip({
    required this.label,
    required this.available,
    required this.selected,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color border;
    if (selected) {
      bg = CoachDashboardTheme.primary;
      fg = Colors.white;
      border = CoachDashboardTheme.primary;
    } else if (available) {
      bg = isDark ? const Color(0xFF181B24) : Colors.white;
      fg = isDark ? Colors.white : CoachDashboardTheme.textPrimary;
      border = CoachDashboardTheme.primary.withValues(alpha: 0.4);
    } else {
      bg = isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF1F2F4);
      fg = isDark ? Colors.white24 : Colors.black26;
      border = Colors.transparent;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: fg,
            decoration: available ? null : TextDecoration.lineThrough,
          ),
        ),
      ),
    );
  }
}
