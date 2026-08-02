import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/api_service.dart';
import '../../../widgets/scrollable_body.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';

class CoachWorkoutReviewTab extends StatefulWidget {
  const CoachWorkoutReviewTab({super.key});

  @override
  State<CoachWorkoutReviewTab> createState() => _CoachWorkoutReviewTabState();
}

class _CoachWorkoutReviewTabState extends State<CoachWorkoutReviewTab> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _pending = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _api.getPendingWorkoutSubmissions();
      if (mounted) {
        setState(() {
          _pending = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiService.friendlyError(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _review(Map<String, dynamic> item, String status) async {
    final id = item['_id']?.toString() ?? '';
    final source = item['source']?.toString() ?? 'exercise_plan';
    if (id.isEmpty) return;

    final feedbackCtrl = TextEditingController(text: item['coachFeedback']?.toString() ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(status == 'approved' ? 'Approve workout' : 'Request changes'),
          content: TextField(
            controller: feedbackCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: status == 'approved' ? 'Feedback (optional)' : 'Feedback for user',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: status == 'approved'
                    ? CoachDashboardTheme.success
                    : CoachDashboardTheme.warning,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(status == 'approved' ? 'Approve' : 'Send back'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      await _api.reviewWorkoutSubmission(
        id: id,
        source: source,
        status: status,
        feedback: feedbackCtrl.text.trim(),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved' ? 'Workout approved' : 'Sent back for resubmit'),
            backgroundColor: status == 'approved'
                ? CoachDashboardTheme.success
                : CoachDashboardTheme.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  ImageProvider? _proofImage(String? photo) {
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

  String _formatWhen(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return '—';
    return DateFormat('EEE, MMM d · h:mm a').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CoachPage(
      title: 'Workout Review',
      actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      body: _isLoading
          ? const ScrollableCenter(child: CircularProgressIndicator(color: CoachDashboardTheme.primary))
          : _error != null
              ? ScrollableCenter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _pending.isEmpty
                  ? CoachDashboardTheme.emptyState(
                      icon: Icons.task_alt_rounded,
                      title: 'All caught up',
                      message: 'No workout submissions awaiting review.',
                      isDark: isDark,
                    )
                  : ListView.builder(
                      physics: dashboardScrollPhysics,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _pending.length,
                      itemBuilder: (context, index) {
                        final item = Map<String, dynamic>.from(_pending[index] as Map);
                        final userMap = item['user'] is Map
                            ? Map<dynamic, dynamic>.from(item['user'] as Map)
                            : null;
                        final clientName = ApiService.displayName(userMap, fallback: 'Client');
                        final title = item['title']?.toString() ?? 'Workout';
                        final notes = item['notes']?.toString().trim() ?? '';
                        final duration = item['durationMinutes'];
                        final submitted = _formatWhen(item['submittedAt'] ?? item['createdAt']);
                        final proof = _proofImage(item['proofPhoto']?.toString());
                        final details = item['workoutDetails'];
                        final exercises = details is Map
                            ? (details['exercises'] as List? ??
                                details['workoutTemplate']?['exercises'] as List? ??
                                const [])
                            : const [];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: CoachDashboardTheme.cardDecoration(isDark),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: CoachDashboardTheme.warning.withValues(alpha: 0.15),
                                    child: Text(
                                      clientName.isNotEmpty ? clientName[0].toUpperCase() : 'C',
                                      style: const TextStyle(
                                        color: CoachDashboardTheme.warning,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(clientName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                        Text(title, style: CoachDashboardTheme.bodyMuted(isDark)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: CoachDashboardTheme.warning.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Pending Review',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: CoachDashboardTheme.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 14,
                                runSpacing: 6,
                                children: [
                                  if (duration != null)
                                    Text('⏱ $duration min', style: const TextStyle(fontSize: 12)),
                                  Text('📅 $submitted', style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                              if (notes.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text('Notes', style: CoachDashboardTheme.sectionTitle(isDark)),
                                const SizedBox(height: 4),
                                Text(notes, style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? Colors.white70 : Colors.black87)),
                              ],
                              if (proof != null) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Image(image: proof, fit: BoxFit.cover),
                                  ),
                                ),
                              ],
                              if (exercises.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text('Workout details', style: CoachDashboardTheme.sectionTitle(isDark)),
                                const SizedBox(height: 6),
                                ...exercises.take(6).map((ex) {
                                  final name = ex is Map ? (ex['name']?.toString() ?? 'Exercise') : ex.toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text('• $name', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black87)),
                                  );
                                }),
                              ],
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _review(item, 'rejected'),
                                      style: OutlinedButton.styleFrom(foregroundColor: CoachDashboardTheme.danger),
                                      child: const Text('Send back'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: CoachDashboardTheme.success,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => _review(item, 'approved'),
                                      child: const Text('Approve'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
