import 'package:flutter/material.dart';
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
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _api.getPendingActivities();
      if (mounted) setState(() { _pending = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.friendlyError(e); _isLoading = false; });
    }
  }

  Future<void> _review(String id, String status) async {
    try {
      await _api.updateActivityStatus(id, status);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved' ? 'Workout approved' : 'Workout rejected'),
            backgroundColor: status == 'approved' ? Colors.green : Colors.orange,
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

  @override
  Widget build(BuildContext context) {
    return CoachPage(
      title: 'Workout Review',
      actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      body: _isLoading
          ? const ScrollableCenter(child: CircularProgressIndicator())
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
                  ? const ScrollableCenter(child: Text('No pending workouts to review.'))
                  : ListView.builder(
                      physics: dashboardScrollPhysics,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _pending.length,
                      itemBuilder: (context, index) {
                        final item = _pending[index] as Map<String, dynamic>;
                        final userMap = item['user'] is Map
                            ? Map<dynamic, dynamic>.from(item['user'] as Map)
                            : null;
                        final clientName = ApiService.displayName(userMap, fallback: 'Client');
                        final type = item['activityType'] ?? 'Workout';
                        final duration = item['durationMinutes'] ?? 0;
                        final calories = item['caloriesBurned'] ?? 0;
                        final id = item['_id']?.toString() ?? '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('$type · $duration min · $calories kcal burned'),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _review(id, 'rejected'),
                                        child: const Text('Reject'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: CoachDashboardTheme.success,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => _review(id, 'approved'),
                                        child: const Text('Approve'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
