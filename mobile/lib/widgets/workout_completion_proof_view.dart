import 'dart:convert';

import 'package:flutter/material.dart';

import '../screens/dashboard/widgets/coach_home/coach_dashboard_theme.dart';
import '../utils/date_utils.dart';

/// Decode a proof photo from API data URL or http URL.
ImageProvider? workoutProofImageProvider(String? photo) {
  if (photo == null || photo.isEmpty) return null;
  if (photo.startsWith('data:image')) {
    try {
      final b64 = photo.substring(photo.indexOf(',') + 1);
      return MemoryImage(base64Decode(b64));
    } catch (_) {
      return null;
    }
  }
  if (photo.startsWith('http')) return NetworkImage(photo);
  return null;
}

/// Displays submitted workout proof (photo, notes, duration, timestamps).
class WorkoutCompletionProofView extends StatelessWidget {
  final Map<String, dynamic> completion;
  final bool isDark;
  final String? title;

  const WorkoutCompletionProofView({
    super.key,
    required this.completion,
    required this.isDark,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final notes = completion['notes']?.toString().trim() ?? '';
    final duration = completion['durationMinutes'];
    final submittedAt = completion['submittedAt']?.toString();
    final completedAt = completion['completedAt']?.toString();
    final reviewedAt = completion['reviewedAt']?.toString();
    final feedback = completion['coachFeedback']?.toString().trim() ?? '';
    final hasPhoto = completion['proofPhoto']?.toString().isNotEmpty == true ||
        completion['hasProofPhoto'] == true;
    final proof = workoutProofImageProvider(completion['proofPhoto']?.toString());

    if (!hasPhoto && notes.isEmpty && duration == null && submittedAt == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title!, style: CoachDashboardTheme.sectionTitle(isDark)),
          const SizedBox(height: 8),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: CoachDashboardTheme.cardDecoration(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (proof != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image(image: proof, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (hasPhoto) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isDark ? Colors.white10 : const Color(0xFFF5F6F9),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_camera_rounded, size: 18, color: isDark ? Colors.white54 : Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Workout photo submitted',
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : CoachDashboardTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (duration != null)
                _proofRow(isDark, Icons.timer_outlined, 'Duration', '$duration min'),
              if (notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Text(notes, style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? Colors.white70 : CoachDashboardTheme.textPrimary)),
                    ],
                  ),
                ),
              if (submittedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _proofRow(isDark, Icons.upload_rounded, 'Submitted', formatApiDateTime(submittedAt)),
                ),
              if (completedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _proofRow(isDark, Icons.check_circle_outline_rounded, 'Approved', formatApiDateTime(completedAt)),
                ),
              if (reviewedAt != null && completedAt == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _proofRow(isDark, Icons.rate_review_outlined, 'Reviewed', formatApiDateTime(reviewedAt)),
                ),
              if (feedback.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Coach feedback', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary)),
                const SizedBox(height: 4),
                Text(feedback, style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? Colors.white70 : CoachDashboardTheme.textPrimary)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _proofRow(bool isDark, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: CoachDashboardTheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : CoachDashboardTheme.textPrimary),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Merge proof photos from progress history into workout completion maps (no API changes).
void enrichWorkoutsWithHistoryProof(
  List<Map<String, dynamic>> workouts,
  List<Map<String, dynamic>> history,
) {
  final historyById = <String, Map<String, dynamic>>{
    for (final item in history)
      if (item['_id'] != null) item['_id'].toString(): item,
  };

  for (var i = 0; i < workouts.length; i++) {
    final workout = Map<String, dynamic>.from(workouts[i]);
    if (workout['completion'] is Map) {
      workout['completion'] = _mergeCompletion(
        Map<String, dynamic>.from(workout['completion'] as Map),
        historyById,
      );
    }
    if (workout['days'] is List) {
      final days = <Map<String, dynamic>>[];
      for (final raw in workout['days'] as List) {
        if (raw is! Map) continue;
        final day = Map<String, dynamic>.from(raw);
        if (day['completion'] is Map) {
          day['completion'] = _mergeCompletion(
            Map<String, dynamic>.from(day['completion'] as Map),
            historyById,
          );
        }
        days.add(day);
      }
      workout['days'] = days;
    }
    workouts[i] = workout;
  }
}

Map<String, dynamic> _mergeCompletion(
  Map<String, dynamic> completion,
  Map<String, Map<String, dynamic>> historyById,
) {
  final id = completion['_id']?.toString();
  if (id == null || id.isEmpty) return completion;
  final historyItem = historyById[id];
  if (historyItem == null) return completion;

  if ((completion['proofPhoto']?.toString().isEmpty ?? true) &&
      (historyItem['proofPhoto']?.toString().isNotEmpty ?? false)) {
    completion['proofPhoto'] = historyItem['proofPhoto'];
  }
  if (completion['notes']?.toString().trim().isEmpty ?? true) {
    final notes = historyItem['notes']?.toString();
    if (notes != null && notes.isNotEmpty) completion['notes'] = notes;
  }
  if (completion['durationMinutes'] == null && historyItem['durationMinutes'] != null) {
    completion['durationMinutes'] = historyItem['durationMinutes'];
  }
  if (completion['submittedAt'] == null && historyItem['submittedAt'] != null) {
    completion['submittedAt'] = historyItem['submittedAt'];
  }
  if (completion['coachFeedback']?.toString().trim().isEmpty ?? true) {
    final feedback = historyItem['coachFeedback']?.toString();
    if (feedback != null && feedback.isNotEmpty) completion['coachFeedback'] = feedback;
  }
  return completion;
}
