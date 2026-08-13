import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../screens/dashboard/widgets/coach_home/coach_dashboard_theme.dart';

/// Collects required workout proof: photo, notes, duration.
/// Returns a map `{ notes, durationMinutes, proofPhoto }` or null if cancelled.
Future<Map<String, dynamic>?> showWorkoutProofSheet(
  BuildContext context, {
  required String workoutTitle,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (ctx) => _WorkoutProofSheet(workoutTitle: workoutTitle),
  );
}

class _WorkoutProofSheet extends StatefulWidget {
  final String workoutTitle;

  const _WorkoutProofSheet({required this.workoutTitle});

  @override
  State<_WorkoutProofSheet> createState() => _WorkoutProofSheetState();
}

class _WorkoutProofSheetState extends State<_WorkoutProofSheet> {
  final _notesCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '30');
  final _picker = ImagePicker();
  String? _proofPhoto;
  bool _picking = false;

  bool get _hasPhoto => _proofPhoto != null && _proofPhoto!.isNotEmpty;
  bool get _hasNotes => _notesCtrl.text.trim().isNotEmpty;
  bool get _hasDuration => (int.tryParse(_durationCtrl.text.trim()) ?? 0) >= 1;
  bool get _canSubmit => _hasPhoto && _hasNotes && _hasDuration;

  @override
  void initState() {
    super.initState();
    _notesCtrl.addListener(() => setState(() {}));
    _durationCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _picking = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 72,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ext = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      setState(() {
        _proofPhoto = 'data:image/$ext;base64,${base64Encode(bytes)}';
      });
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.pop(context, {
      'notes': _notesCtrl.text.trim(),
      'durationMinutes': int.parse(_durationCtrl.text.trim()),
      'proofPhoto': _proofPhoto,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D27) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Mark workout complete',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : CoachDashboardTheme.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : CoachDashboardTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.workoutTitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _ChecklistStep(
                isDark: isDark,
                done: true,
                label: 'Mark as completed',
                detail: 'Confirm you finished this workout',
              ),
              _ChecklistStep(
                isDark: isDark,
                done: _hasPhoto,
                label: 'Upload workout photo',
                detail: 'Required proof for your coach',
              ),
              _ChecklistStep(
                isDark: isDark,
                done: _hasNotes,
                label: 'Add workout notes',
                detail: 'How it went, form notes, or modifications',
              ),
              _ChecklistStep(
                isDark: isDark,
                done: _hasDuration,
                label: 'Enter duration',
                detail: 'Time spent in minutes',
              ),
              const SizedBox(height: 16),
              Text('Workout photo *', style: CoachDashboardTheme.sectionTitle(isDark)),
              const SizedBox(height: 8),
              if (_hasPhoto)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.memory(
                      base64Decode(_proofPhoto!.substring(_proofPhoto!.indexOf(',') + 1)),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                    color: isDark ? Colors.white10 : const Color(0xFFF5F6F9),
                  ),
                  child: Text(
                          'No photo selected',
                          style: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                        ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _picking ? null : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Gallery'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _picking ? null : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Camera'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: CoachDashboardTheme.fieldDecoration(
                  isDark: isDark,
                  label: 'Workout notes *',
                  hint: 'How did it go? Any form notes or modifications…',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _durationCtrl,
                keyboardType: TextInputType.number,
                decoration: CoachDashboardTheme.fieldDecoration(
                  isDark: isDark,
                  label: 'Duration (minutes) *',
                  hint: 'e.g. 45',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Submission time is recorded automatically. Your streak updates when your coach approves the workout.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: CoachDashboardTheme.primaryButtonStyle(),
                  onPressed: _canSubmit ? _submit : null,
                  child: Text(
                    _canSubmit ? 'Submit completion' : 'Complete all required fields',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistStep extends StatelessWidget {
  final bool isDark;
  final bool done;
  final String label;
  final String detail;

  const _ChecklistStep({
    required this.isDark,
    required this.done,
    required this.label,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: done ? CoachDashboardTheme.success : (isDark ? Colors.white38 : Colors.grey),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : CoachDashboardTheme.textPrimary,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
