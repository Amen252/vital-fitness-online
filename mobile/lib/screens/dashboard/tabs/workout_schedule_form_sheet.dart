import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../utils/date_utils.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';

class WorkoutScheduleFormSheet extends StatefulWidget {
  final List<dynamic> templates;
  final List<dynamic> clients;
  final List<dynamic> classes;
  final ApiService apiService;
  final VoidCallback onSaved;
  final Map<String, dynamic>? existingSchedule;
  final String? preselectedClientId;
  final String? preselectedClassId;

  const WorkoutScheduleFormSheet({
    super.key,
    required this.templates,
    required this.clients,
    required this.classes,
    required this.apiService,
    required this.onSaved,
    this.existingSchedule,
    this.preselectedClientId,
    this.preselectedClassId,
  });

  @override
  State<WorkoutScheduleFormSheet> createState() => _WorkoutScheduleFormSheetState();
}

class _WorkoutScheduleFormSheetState extends State<WorkoutScheduleFormSheet> {
  final _notesController = TextEditingController();

  bool _isSubmitting = false;
  bool _assignToGroup = false;
  String? _selectedTemplateId;
  String? _selectedClientId;
  String? _selectedClassId;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  bool _reminderEnabled = true;
  int _reminderMinutes = 30;

  bool get _isEditing => widget.existingSchedule != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final s = widget.existingSchedule!;
      _notesController.text = s['notes']?.toString() ?? '';
      _assignToGroup = s['fitnessClass'] != null;
      _selectedTemplateId = s['workoutTemplate']?['_id']?.toString() ?? s['workoutTemplate']?.toString();
      _selectedClientId = s['client']?['_id']?.toString() ?? s['client']?.toString();
      _selectedClassId = s['fitnessClass']?['_id']?.toString() ?? s['fitnessClass']?.toString();
      _reminderEnabled = s['reminderEnabled'] as bool? ?? true;
      _reminderMinutes = s['reminderMinutesBefore'] as int? ?? 30;
      final start = parseApiDateTime(s['startDateTime']?.toString());
      final end = parseApiDateTime(s['endDateTime']?.toString());
      if (start != null) {
        _selectedDate = DateTime(start.year, start.month, start.day);
        _startTime = TimeOfDay(hour: start.hour, minute: start.minute);
      }
      if (end != null) {
        _endTime = TimeOfDay(hour: end.hour, minute: end.minute);
      }
    } else {
      _assignToGroup = widget.preselectedClassId != null;
      _selectedClientId = widget.preselectedClientId;
      _selectedClassId = widget.preselectedClassId;
      if (widget.templates.isNotEmpty) {
        _selectedTemplateId = widget.templates.first['_id']?.toString();
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  int get _durationMinutes {
    final start = _startDateTime;
    var end = _endDateTime;
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    return end.difference(start).inMinutes;
  }

  DateTime get _startDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

  DateTime get _endDateTime {
    var end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _endTime.hour, _endTime.minute);
    if (!end.isAfter(_startDateTime)) end = end.add(const Duration(days: 1));
    return end;
  }

  Map<String, dynamic>? get _selectedTemplate {
    if (_selectedTemplateId == null) return null;
    return widget.templates.cast<Map>().firstWhere(
          (t) => t['_id']?.toString() == _selectedTemplateId,
          orElse: () => <String, dynamic>{},
        ) as Map<String, dynamic>?;
  }

  Future<void> _submit() async {
    if (_selectedTemplateId == null || _selectedTemplateId!.isEmpty) {
      _showError('Select a workout');
      return;
    }
    if (!_assignToGroup && (_selectedClientId == null || _selectedClientId!.isEmpty)) {
      _showError('Select a user');
      return;
    }
    if (_assignToGroup && (_selectedClassId == null || _selectedClassId!.isEmpty)) {
      _showError('Select a group');
      return;
    }

    setState(() => _isSubmitting = true);
    final payload = <String, dynamic>{
      'workoutTemplateId': _selectedTemplateId,
      'startDateTime': toApiDateTime(_startDateTime),
      'endDateTime': toApiDateTime(_endDateTime),
      'durationMinutes': _durationMinutes,
      'notes': _notesController.text.trim(),
      'reminderEnabled': _reminderEnabled,
      'reminderMinutesBefore': _reminderMinutes,
    };

    if (_assignToGroup) {
      payload['fitnessClassId'] = _selectedClassId;
    } else {
      payload['clientId'] = _selectedClientId;
    }

    try {
      if (_isEditing) {
        await widget.apiService.updateWorkoutSchedule(widget.existingSchedule!['_id'].toString(), payload);
      } else {
        await widget.apiService.createWorkoutSchedule(payload);
      }
      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Schedule updated' : 'Schedule created'),
            backgroundColor: CoachDashboardTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showError(ApiService.friendlyError(e));
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: CoachDashboardTheme.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final template = _selectedTemplate;

    return Padding(
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
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit Schedule' : 'Add Schedule',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1. Select workout', style: CoachDashboardTheme.sectionTitle(isDark)),
                    const SizedBox(height: 4),
                    Text(
                      'Then review exercises under that workout title for this session.',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    if (widget.templates.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CoachDashboardTheme.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Create a workout template first in the Workouts tab.'),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedTemplateId,
                        decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Workout title'),
                        items: widget.templates.map((t) {
                          final id = t['_id']?.toString() ?? '';
                          final title = t['title']?.toString() ?? 'Workout';
                          final level = t['level']?.toString() ?? '';
                          return DropdownMenuItem(value: id, child: Text('$title · $level'));
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedTemplateId = v),
                      ),
                    if (template != null && template.isNotEmpty) ...[
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
                            Text(
                              template['title']?.toString() ?? 'Workout',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            if ((template['description'] as String? ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(template['description'].toString(), style: const TextStyle(fontSize: 12)),
                            ],
                            const SizedBox(height: 8),
                            Text('Exercises', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
                            const SizedBox(height: 4),
                            ...(template['exercises'] as List<dynamic>? ?? []).map((ex) {
                              final name = ex['name'] ?? 'Exercise';
                              return Text('• $name — ${ex['sets']}×${ex['reps']}', style: const TextStyle(fontSize: 11, height: 1.35));
                            }),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text('Assign to', style: CoachDashboardTheme.sectionTitle(isDark)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('User')),
                            selected: !_assignToGroup,
                            onSelected: _isEditing ? null : (_) => setState(() => _assignToGroup = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Group')),
                            selected: _assignToGroup,
                            onSelected: _isEditing ? null : (_) => setState(() => _assignToGroup = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_assignToGroup)
                      DropdownButtonFormField<String>(
                        initialValue: _selectedClassId,
                        decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Group'),
                        items: widget.classes.map((cls) {
                          final id = cls['_id']?.toString() ?? '';
                          final title = cls['title']?.toString() ?? 'Group';
                          return DropdownMenuItem(value: id, child: Text(title));
                        }).toList(),
                        onChanged: _isEditing ? null : (v) => setState(() => _selectedClassId = v),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedClientId,
                        decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'User'),
                        items: widget.clients.map((c) {
                          final user = c['user'] as Map<String, dynamic>? ?? {};
                          final id = user['_id']?.toString() ?? '';
                          final name = ApiService.displayName(user, fallback: 'Client');
                          return DropdownMenuItem(value: id, child: Text(name));
                        }).toList(),
                        onChanged: _isEditing ? null : (v) => setState(() => _selectedClientId = v),
                      ),
                    const SizedBox(height: 16),
                    Text('Date & time', style: CoachDashboardTheme.sectionTitle(isDark)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) setState(() => _selectedDate = date);
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text('${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final time = await showTimePicker(context: context, initialTime: _startTime);
                              if (time != null) setState(() => _startTime = time);
                            },
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: Text('Start ${_startTime.format(context)}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final time = await showTimePicker(context: context, initialTime: _endTime);
                              if (time != null) setState(() => _endTime = time);
                            },
                            icon: const Icon(Icons.stop_rounded, size: 18),
                            label: Text('End ${_endTime.format(context)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Duration: $_durationMinutes minutes',
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Text('Coach notes / instructions', style: CoachDashboardTheme.sectionTitle(isDark)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: CoachDashboardTheme.fieldDecoration(
                        isDark: isDark,
                        label: 'Notes for this session',
                        hint: 'Arrive 5 min early, bring water...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Reminder', style: CoachDashboardTheme.sectionTitle(isDark)),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Notify before workout'),
                      value: _reminderEnabled,
                      activeThumbColor: CoachDashboardTheme.primary,
                      onChanged: (v) => setState(() => _reminderEnabled = v),
                    ),
                    if (_reminderEnabled)
                      DropdownButtonFormField<int>(
                        initialValue: _reminderMinutes,
                        decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Remind before'),
                        items: const [
                          DropdownMenuItem(value: 15, child: Text('15 minutes')),
                          DropdownMenuItem(value: 30, child: Text('30 minutes')),
                          DropdownMenuItem(value: 60, child: Text('1 hour')),
                          DropdownMenuItem(value: 120, child: Text('2 hours')),
                        ],
                        onChanged: (v) => setState(() => _reminderMinutes = v ?? 30),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: CoachDashboardTheme.primaryButtonStyle(),
                  onPressed: _isSubmitting || widget.templates.isEmpty ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_isEditing ? 'Save Schedule' : 'Save Schedule'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
