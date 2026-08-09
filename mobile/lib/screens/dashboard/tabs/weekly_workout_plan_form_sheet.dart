import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../utils/date_utils.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';

const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

class _DayConfig {
  bool enabled;
  bool offDay;
  /// Exercise keys selected for this day (stable key from template exercise).
  final Set<String> selectedKeys;
  TimeOfDay start;
  TimeOfDay end;
  String notes;

  _DayConfig({
    this.enabled = false,
    this.offDay = false,
    Set<String>? selectedKeys,
    this.start = const TimeOfDay(hour: 9, minute: 0),
    this.end = const TimeOfDay(hour: 10, minute: 0),
    this.notes = '',
  }) : selectedKeys = selectedKeys ?? <String>{};
}

class WeeklyWorkoutPlanFormSheet extends StatefulWidget {
  final List<dynamic> templates;
  final List<dynamic> clients;
  final List<dynamic> classes;
  final ApiService apiService;
  final Future<void> Function() onSaved;
  final Map<String, dynamic>? existingPlan;
  final Future<void> Function(String id)? onDelete;

  const WeeklyWorkoutPlanFormSheet({
    super.key,
    required this.templates,
    required this.clients,
    required this.classes,
    required this.apiService,
    required this.onSaved,
    this.existingPlan,
    this.onDelete,
  });

  @override
  State<WeeklyWorkoutPlanFormSheet> createState() => _WeeklyWorkoutPlanFormSheetState();
}

class _WeeklyWorkoutPlanFormSheetState extends State<WeeklyWorkoutPlanFormSheet> {
  final _titleController = TextEditingController();
  bool _assignToGroup = false;
  String? _clientId;
  String? _classId;
  String? _workoutTemplateId;
  DateTime _weekStart = defaultWeekStartForNewPlan();
  DateTime? _originalWeekStart;
  bool _reminderEnabled = true;
  int _reminderMinutes = 30;
  bool _submitting = false;
  bool _loadingTemplates = false;
  String? _saveError;
  List<dynamic> _templates = [];
  final List<_DayConfig> _days = List.generate(7, (_) => _DayConfig());

  @override
  void initState() {
    super.initState();
    _templates = List<dynamic>.from(widget.templates);
    _loadTemplates();
    if (widget.existingPlan != null) {
      final p = widget.existingPlan!;
      _titleController.text = p['title']?.toString() ?? '';
      _assignToGroup = p['fitnessClass'] != null;
      _clientId = p['client']?['_id']?.toString() ?? p['client']?.toString();
      _classId = p['fitnessClass']?['_id']?.toString() ?? p['fitnessClass']?.toString();
      _workoutTemplateId = p['workoutTemplate']?['_id']?.toString()
          ?? p['workoutTemplate']?.toString()
          ?? _inferPlanTemplateId(p);
      final ws = parseApiDateOnly(p['weekStartDate']?.toString());
      if (ws != null) {
        _weekStart = dateOnly(mondayOf(ws));
        _originalWeekStart = _weekStart;
      }
      _reminderEnabled = p['reminderEnabled'] as bool? ?? true;
      _reminderMinutes = p['reminderMinutesBefore'] as int? ?? 30;
      final days = p['days'] as List<dynamic>? ?? [];
      for (final day in days) {
        final i = day['dayOfWeek'] as int? ?? 0;
        if (i < 0 || i > 6) continue;
        final st = (day['startTime'] as String? ?? '09:00').split(':');
        final et = (day['endTime'] as String? ?? '10:00').split(':');
        final dayExercises = day['exercises'] as List<dynamic>? ?? [];
        final keys = <String>{};
        for (final ex in dayExercises) {
          if (ex is Map) keys.add(_exerciseKey(Map<String, dynamic>.from(ex)));
        }
        // Legacy day with template but no exercises: preselect all from plan workout
        final enabled = day['enabled'] as bool? ?? false;
        final offDay = day['offDay'] as bool? ?? false;
        if (enabled && !offDay && keys.isEmpty) {
          keys.addAll(_availableExercises.map(_exerciseKey));
        }
        _days[i] = _DayConfig(
          enabled: enabled,
          offDay: offDay,
          selectedKeys: keys,
          start: TimeOfDay(hour: int.tryParse(st[0]) ?? 9, minute: int.tryParse(st[1]) ?? 0),
          end: TimeOfDay(hour: int.tryParse(et[0]) ?? 10, minute: int.tryParse(et[1]) ?? 0),
          notes: day['notes']?.toString() ?? '',
        );
      }
    } else {
      if (widget.classes.isNotEmpty) {
        _classId = widget.classes.first['_id']?.toString();
        _assignToGroup = true;
      } else if (widget.clients.isNotEmpty) {
        final first = widget.clients.first;
        final user = first['user'] as Map<String, dynamic>? ?? {};
        _clientId = user['_id']?.toString();
      }
      if (_templates.isNotEmpty) {
        _workoutTemplateId = _templateId(Map<String, dynamic>.from(_templates.first as Map));
      }
    }
  }

  String? _inferPlanTemplateId(Map<String, dynamic> plan) {
    final days = plan['days'] as List<dynamic>? ?? [];
    for (final day in days) {
      if (day is! Map) continue;
      if (day['enabled'] != true || day['offDay'] == true) continue;
      final id = day['workoutTemplate']?['_id']?.toString() ?? day['workoutTemplate']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  void _ensureTargets() {
    if (_assignToGroup) {
      _classId = _validClassId(_classId) ?? (_classDropdownItems.isNotEmpty ? _classDropdownItems.first.value : null);
    } else {
      _clientId = _validClientId(_clientId) ?? (_clientDropdownItems.isNotEmpty ? _clientDropdownItems.first.value : null);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime d) => formatDateOnly(d);

  Future<void> _loadTemplates() async {
    setState(() => _loadingTemplates = true);
    try {
      final list = await widget.apiService.getWorkoutTemplates();
      if (mounted) {
        setState(() {
          _templates = list;
          _workoutTemplateId ??= list.isNotEmpty ? _templateId(Map<String, dynamic>.from(list.first as Map)) : null;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingTemplates = false);
    }
  }

  String _templateId(Map<String, dynamic> t) => t['_id']?.toString() ?? t['id']?.toString() ?? '';

  Map<String, dynamic>? get _selectedWorkout {
    if (_workoutTemplateId == null) return null;
    for (final raw in _templates) {
      final t = Map<String, dynamic>.from(raw as Map);
      if (_templateId(t) == _workoutTemplateId) return t;
    }
    return null;
  }

  List<Map<String, dynamic>> get _availableExercises {
    final list = _selectedWorkout?['exercises'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  String _exerciseKey(Map<String, dynamic> ex) {
    // Prefer name+sets+reps so day snapshots match template entries after re-save
    return '${ex['name']}|${ex['sets']}|${ex['reps']}';
  }

  String _exerciseLabel(Map<String, dynamic> ex) {
    final name = ex['name']?.toString() ?? 'Exercise';
    final sets = ex['sets'];
    final reps = ex['reps'];
    return '$name · $sets×$reps';
  }

  List<DropdownMenuItem<String>> get _workoutDropdownItems {
    return _templates
        .map((raw) {
          final t = Map<String, dynamic>.from(raw as Map);
          final id = _templateId(t);
          if (id.isEmpty) return null;
          return DropdownMenuItem<String>(
            value: id,
            child: Text(t['title']?.toString() ?? 'Workout', overflow: TextOverflow.ellipsis),
          );
        })
        .whereType<DropdownMenuItem<String>>()
        .toList();
  }

  String? _validSelectedWorkoutId(String? id) {
    if (id == null || id.isEmpty) return null;
    final exists = _workoutDropdownItems.any((item) => item.value == id);
    return exists ? id : null;
  }

  List<DropdownMenuItem<String>> get _clientDropdownItems {
    final seen = <String>{};
    return widget.clients
        .map((raw) {
          final c = Map<String, dynamic>.from(raw as Map);
          final u = c['user'] as Map<String, dynamic>? ?? {};
          final id = u['_id']?.toString() ?? '';
          if (id.isEmpty || seen.contains(id)) return null;
          seen.add(id);
          return DropdownMenuItem(value: id, child: Text(ApiService.displayName(u, fallback: 'Client')));
        })
        .whereType<DropdownMenuItem<String>>()
        .toList();
  }

  List<DropdownMenuItem<String>> get _classDropdownItems {
    final seen = <String>{};
    return widget.classes
        .map((raw) {
          final c = Map<String, dynamic>.from(raw as Map);
          final id = c['_id']?.toString() ?? '';
          if (id.isEmpty || seen.contains(id)) return null;
          seen.add(id);
          return DropdownMenuItem(value: id, child: Text(c['title']?.toString() ?? 'Group'));
        })
        .whereType<DropdownMenuItem<String>>()
        .toList();
  }

  String? _validClientId(String? id) {
    if (id == null || id.isEmpty) return null;
    return _clientDropdownItems.any((item) => item.value == id) ? id : null;
  }

  String? _validClassId(String? id) {
    if (id == null || id.isEmpty) return null;
    return _classDropdownItems.any((item) => item.value == id) ? id : null;
  }

  void _onWorkoutChanged(String? id) {
    setState(() {
      _workoutTemplateId = id;
      for (final d in _days) {
        d.selectedKeys.clear();
      }
      if (_titleController.text.trim().isEmpty && _selectedWorkout != null) {
        _titleController.text = _selectedWorkout!['title']?.toString() ?? '';
      }
    });
  }

  void _setDayMode(int i, String mode) {
    setState(() {
      final d = _days[i];
      switch (mode) {
        case 'workout':
          d.offDay = false;
          d.enabled = true;
          if (d.selectedKeys.isEmpty && _availableExercises.isNotEmpty) {
            // Soft start: don't auto-select all — coach picks per day
          }
          break;
        case 'off':
          d.offDay = true;
          d.enabled = false;
          d.selectedKeys.clear();
          break;
        default:
          d.offDay = false;
          d.enabled = false;
          d.selectedKeys.clear();
      }
    });
  }

  String _dayMode(int i) {
    final d = _days[i];
    if (d.offDay) return 'off';
    if (d.enabled) return 'workout';
    return 'rest';
  }

  void _toggleExercise(int dayIndex, Map<String, dynamic> ex) {
    final key = _exerciseKey(ex);
    setState(() {
      final d = _days[dayIndex];
      d.enabled = true;
      d.offDay = false;
      if (d.selectedKeys.contains(key)) {
        d.selectedKeys.remove(key);
      } else {
        d.selectedKeys.add(key);
      }
    });
  }

  List<Map<String, dynamic>> _exercisesForDay(int i) {
    final keys = _days[i].selectedKeys;
    return _availableExercises.where((ex) => keys.contains(_exerciseKey(ex))).toList();
  }

  Future<void> _submit() async {
    setState(() => _saveError = null);
    _ensureTargets();

    if (_templates.isEmpty) {
      _err('Create workout templates first');
      return;
    }
    if (_workoutTemplateId == null || _workoutTemplateId!.isEmpty) {
      _err('Select a workout title first');
      return;
    }
    if (!_assignToGroup && (_clientId == null || _clientId!.isEmpty)) {
      _err('Select a user');
      return;
    }
    if (_assignToGroup && (_classId == null || _classId!.isEmpty)) {
      _err('Select a group');
      return;
    }
    for (var i = 0; i < 7; i++) {
      final d = _days[i];
      if (d.enabled && !d.offDay && d.selectedKeys.isEmpty) {
        _err('Assign at least one exercise for ${_dayNames[i]}');
        return;
      }
    }
    if (!_days.any((d) => d.enabled && !d.offDay && d.selectedKeys.isNotEmpty)) {
      _err('Enable at least one day and assign exercises');
      return;
    }

    setState(() => _submitting = true);
    try {
      if (widget.existingPlan != null && _originalWeekStart != null && !_sameDay(_weekStart, _originalWeekStart!)) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Reschedule week?'),
            content: const Text('Changing the week will cancel existing schedule entries and create new ones for the selected week.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reschedule')),
            ],
          ),
        );
        if (confirm != true) {
          return;
        }
      }

      final workoutTitle = _selectedWorkout?['title']?.toString() ?? 'Weekly Workout Plan';
      final payload = <String, dynamic>{
        'title': _titleController.text.trim().isEmpty ? workoutTitle : _titleController.text.trim(),
        'workoutTemplateId': _workoutTemplateId,
        'weekStartDate': _fmtDate(_weekStart),
        'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        'reminderEnabled': _reminderEnabled,
        'reminderMinutesBefore': _reminderMinutes,
        'days': List.generate(7, (i) {
          final day = _days[i];
          final exercises = _exercisesForDay(i);
          final hasWorkout = day.enabled && !day.offDay && exercises.isNotEmpty;
          return {
            'dayOfWeek': i,
            'enabled': hasWorkout,
            'offDay': day.offDay,
            if (hasWorkout) 'workoutTemplateId': _workoutTemplateId,
            if (hasWorkout) 'exercises': exercises,
            'startTime': _fmt(day.start),
            'endTime': _fmt(day.end),
            'notes': day.notes,
          };
        }),
      };
      if (_assignToGroup) {
        payload['fitnessClassId'] = _classId;
      } else {
        payload['clientId'] = _clientId;
      }

      if (widget.existingPlan != null) {
        await widget.apiService.updateWeeklyWorkoutPlan(widget.existingPlan!['_id'].toString(), payload);
      } else {
        await widget.apiService.createWeeklyWorkoutPlan(payload);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      widget.onSaved().catchError((_) {});
    } catch (e) {
      if (mounted) {
        _err(ApiService.friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _err(String m) {
    setState(() => _saveError = m);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: CoachDashboardTheme.danger),
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _deletePlan() async {
    final id = widget.existingPlan?['_id']?.toString();
    if (id == null || widget.onDelete == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete weekly plan?'),
        content: const Text('This cancels all linked schedule entries for this plan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: CoachDashboardTheme.danger))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _submitting = true);
    try {
      await widget.onDelete!(id);
      if (mounted) {
        await widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Weekly plan deleted'), backgroundColor: CoachDashboardTheme.success));
      }
    } catch (e) {
      if (mounted) {
        _err(ApiService.friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final workout = _selectedWorkout;
    final workoutTitle = workout?['title']?.toString() ?? 'Workout';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181B24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 8, 0),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      widget.existingPlan != null ? 'Edit Weekly Plan' : 'Weekly Workout Plan',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Structure: Workout Title → Days → Exercises',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleController,
                        decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Plan title (optional)', hint: 'Week 1 Strength'),
                      ),
                      const SizedBox(height: 12),
                      Text('1. Select workout', style: CoachDashboardTheme.sectionTitle(isDark)),
                      const SizedBox(height: 8),
                      if (_loadingTemplates)
                        const LinearProgressIndicator(color: CoachDashboardTheme.primary)
                      else if (_templates.isEmpty)
                        Text(
                          'Create workout templates in the Workouts tab first.',
                          style: TextStyle(fontSize: 12, color: CoachDashboardTheme.warning),
                        )
                      else
                        DropdownButtonFormField<String>(
                          key: ValueKey('workout-$_workoutTemplateId'),
                          initialValue: _validSelectedWorkoutId(_workoutTemplateId),
                          decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Workout title'),
                          items: _workoutDropdownItems,
                          onChanged: _onWorkoutChanged,
                        ),
                      if (workout != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: CoachDashboardTheme.primary.withValues(alpha: isDark ? 0.08 : 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(workoutTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                              if ((workout['description'] as String? ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(workout['description'].toString(), style: const TextStyle(fontSize: 12)),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                'Available exercises (${_availableExercises.length})',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54),
                              ),
                              const SizedBox(height: 4),
                              if (_availableExercises.isEmpty)
                                const Text('This workout has no exercises yet.', style: TextStyle(fontSize: 12))
                              else
                                ..._availableExercises.map(
                                  (ex) => Text('• ${_exerciseLabel(ex)}', style: const TextStyle(fontSize: 12, height: 1.4)),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text('Assign to', style: CoachDashboardTheme.sectionTitle(isDark)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('User')),
                            selected: !_assignToGroup,
                            onSelected: widget.existingPlan != null ? null : (_) => setState(() => _assignToGroup = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Group')),
                            selected: _assignToGroup,
                            onSelected: widget.existingPlan != null
                                ? null
                                : (_) => setState(() {
                                      _assignToGroup = true;
                                      _ensureTargets();
                                    }),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      if (_assignToGroup)
                        DropdownButtonFormField<String>(
                          key: ValueKey('class-$_classId-${widget.classes.length}'),
                          initialValue: _validClassId(_classId),
                          decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Group'),
                          items: _classDropdownItems,
                          onChanged: widget.existingPlan != null ? null : (v) => setState(() => _classId = v),
                        )
                      else
                        DropdownButtonFormField<String>(
                          key: ValueKey('client-$_clientId-${widget.clients.length}'),
                          initialValue: _validClientId(_clientId),
                          decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'User'),
                          items: _clientDropdownItems,
                          onChanged: widget.existingPlan != null ? null : (v) => setState(() => _clientId = v),
                        ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final today = dateOnly(DateTime.now());
                          final d = await showDatePicker(
                            context: context,
                            initialDate: dateOnly(_weekStart),
                            firstDate: today.subtract(const Duration(days: 7)),
                            lastDate: today.add(const Duration(days: 365)),
                          );
                          if (d != null) setState(() => _weekStart = dateOnly(mondayOf(d)));
                        },
                        icon: const Icon(Icons.date_range, size: 18),
                        label: Text('Week of ${formatWeekRange(_weekStart)}'),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Workout reminders'),
                        subtitle: const Text('Notify users before each scheduled session'),
                        value: _reminderEnabled,
                        activeThumbColor: CoachDashboardTheme.primary,
                        onChanged: (v) => setState(() => _reminderEnabled = v),
                      ),
                      if (_reminderEnabled)
                        DropdownButtonFormField<int>(
                          initialValue: _reminderMinutes,
                          decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Remind before'),
                          items: const [15, 30, 45, 60]
                              .map((m) => DropdownMenuItem(value: m, child: Text('$m minutes')))
                              .toList(),
                          onChanged: (v) => setState(() => _reminderMinutes = v ?? 30),
                        ),
                      const SizedBox(height: 16),
                      Text('2. Assign exercises by day', style: CoachDashboardTheme.sectionTitle(isDark)),
                      const SizedBox(height: 4),
                      Text(
                        'For each day under “$workoutTitle”, tap the exercises that belong on that day.',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(7, (i) => _dayCard(i, isDark, workoutTitle)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [
                    if (_saveError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CoachDashboardTheme.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: CoachDashboardTheme.danger.withValues(alpha: 0.3)),
                        ),
                        child: Text(_saveError!, style: const TextStyle(color: CoachDashboardTheme.danger, fontSize: 13)),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (widget.existingPlan != null && widget.onDelete != null) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _submitting ? null : _deletePlan,
                          icon: const Icon(Icons.delete_outline, color: CoachDashboardTheme.danger),
                          label: const Text('Delete Weekly Plan', style: TextStyle(color: CoachDashboardTheme.danger)),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: CoachDashboardTheme.primaryButtonStyle(),
                        onPressed: _submitting || _templates.isEmpty ? null : _submit,
                        child: _submitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Save Weekly Plan'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayCard(int i, bool isDark, String workoutTitle) {
    final d = _days[i];
    final mode = _dayMode(i);
    final assigned = mode == 'workout' && d.selectedKeys.isNotEmpty;
    final dayDate = weekDayDate(_weekStart, i);
    final isOff = mode == 'off';
    final dayExercises = _exercisesForDay(i);

    Color borderColor;
    Color? fillColor;
    if (assigned) {
      borderColor = CoachDashboardTheme.primary.withValues(alpha: 0.5);
      fillColor = CoachDashboardTheme.primary.withValues(alpha: isDark ? 0.06 : 0.04);
    } else if (isOff) {
      borderColor = Colors.blueGrey.withValues(alpha: 0.45);
      fillColor = Colors.blueGrey.withValues(alpha: isDark ? 0.12 : 0.08);
    } else {
      borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
      fillColor = null;
    }

    return Container(
      key: ValueKey('day-$i-$mode-${d.selectedKeys.length}-$_workoutTemplateId'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: assigned || isOff ? 1.5 : 1),
        borderRadius: BorderRadius.circular(10),
        color: fillColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_dayNames[i], style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(formatDisplayDate(dayDate), style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey)),
          if (assigned)
            Text(
              '$workoutTitle · ${dayExercises.length} exercise(s) · ${_fmt(d.start)}–${_fmt(d.end)}',
              style: const TextStyle(fontSize: 11, color: CoachDashboardTheme.primary),
            ),
          if (isOff)
            const Text('Off day / holiday — no workout', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
          if (mode == 'rest')
            Text('Rest day', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(label: const Text('Workout'), selected: mode == 'workout', onSelected: (_) => _setDayMode(i, 'workout')),
              ChoiceChip(label: const Text('Off day'), selected: mode == 'off', onSelected: (_) => _setDayMode(i, 'off')),
              ChoiceChip(label: const Text('Rest'), selected: mode == 'rest', onSelected: (_) => _setDayMode(i, 'rest')),
            ],
          ),
          if (mode == 'workout') ...[
            const SizedBox(height: 10),
            Text(
              'Exercises for ${_dayNames[i]}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              'Check the exercises for this day',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey),
            ),
            const SizedBox(height: 6),
            if (_workoutTemplateId == null)
              const Text('Select a workout title above first.', style: TextStyle(fontSize: 12))
            else if (_availableExercises.isEmpty)
              const Text('No exercises in this workout.', style: TextStyle(fontSize: 12))
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < _availableExercises.length; index++) ...[
                      if (index > 0) Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
                      Builder(
                        builder: (_) {
                          final ex = _availableExercises[index];
                          final key = _exerciseKey(ex);
                          final selected = d.selectedKeys.contains(key);
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: CoachDashboardTheme.primary,
                            value: selected,
                            title: Text(_exerciseLabel(ex), style: const TextStyle(fontSize: 13)),
                            onChanged: (_) => _toggleExercise(i, ex),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            if (d.selectedKeys.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${d.selectedKeys.length} exercise(s) selected for ${_dayNames[i]}',
                style: const TextStyle(fontSize: 11, color: CoachDashboardTheme.primary, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: d.start);
                    if (t != null) setState(() => d.start = t);
                  },
                  child: Text('Start ${_fmt(d.start)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: d.end);
                    if (t != null) setState(() => d.end = t);
                  },
                  child: Text('End ${_fmt(d.end)}'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('notes-$i-${d.notes}'),
              initialValue: d.notes,
              decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Coach notes (optional)', hint: 'Focus on form, warm up…'),
              maxLines: 2,
              onChanged: (v) => d.notes = v,
            ),
          ],
        ],
      ),
    );
  }
}
