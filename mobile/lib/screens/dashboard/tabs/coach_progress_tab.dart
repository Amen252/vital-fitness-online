import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/scrollable_body.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';

class CoachProgressTab extends StatefulWidget {
  final String? clientId;
  final String? clientName;

  const CoachProgressTab({super.key, this.clientId, this.clientName});

  @override
  State<CoachProgressTab> createState() => _CoachProgressTabState();
}

class _CoachProgressTabState extends State<CoachProgressTab> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _clients = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchProgressData();
  }

  Future<void> _fetchProgressData() async {
    setState(() => _isLoading = true);
    try {
      final clients = await _apiService.getCoachClients();
      if (mounted) {
        setState(() {
          if (widget.clientId != null) {
            _clients = clients.where((client) {
              final userId = client['user']?['_id']?.toString();
              final assignmentId = client['_id']?.toString();
              return userId == widget.clientId || assignmentId == widget.clientId;
            }).toList();
          } else {
            _clients = clients;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CoachPage(
      title: widget.clientName != null ? '${widget.clientName} Progress' : 'Client Progress',
      actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchProgressData)],
      body: _isLoading
          ? const ScrollableCenter(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? ScrollableCenter(child: Text('Error: $_errorMessage'))
              : _clients.isEmpty
          ? ScrollableCenter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.show_chart, size: 64, color: isDark ? Colors.white30 : Colors.black26),
                  const SizedBox(height: 16),
                  const Text('No client progress data available.'),
                ],
              ),
            )
          : ListView.builder(
              physics: dashboardScrollPhysics,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _clients.length,
              itemBuilder: (context, index) {
                final client = _clients[index];
                final userMap = client['user'] is Map
                    ? Map<dynamic, dynamic>.from(client['user'] as Map)
                    : null;
                final clientName = ApiService.displayName(userMap, fallback: 'Client');
                final snapshot = client['snapshot'];
                final needsAction = snapshot?['analysis']?['isActionRequired'] == true;
                
                final calsIn = snapshot?['summary']?['caloriesIn'] ?? 0;
                final calsOut = snapshot?['summary']?['caloriesOut'] ?? 0;
                final netCals = snapshot?['summary']?['netCalories'] ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: needsAction ? const Color(0xFFFF6B6B).withOpacity(0.2) : const Color(0xFF2ECC71).withOpacity(0.2),
                      child: Text(
                        clientName.isNotEmpty ? clientName[0].toUpperCase() : 'C',
                        style: TextStyle(color: needsAction ? const Color(0xFFFF6B6B) : const Color(0xFF2ECC71), fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(needsAction ? 'Needs Review' : 'On Track', style: TextStyle(color: needsAction ? const Color(0xFFFF6B6B) : const Color(0xFF2ECC71))),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Recent Summary (Last 7 Days)', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatColumn('Cal In', '$calsIn kcal', const Color(0xFF48C6EF)),
                                _buildStatColumn('Cal Out', '$calsOut kcal', const Color(0xFFF7B731)),
                                _buildStatColumn('Net', '$netCals kcal', const Color(0xFF6C63FF)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.rate_review),
                                label: const Text('Send Feedback'),
                                onPressed: () {
                                  _showFeedbackDialog(client['_id']);
                                },
                              ),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  void _showFeedbackDialog(String assignmentId) {
    final controller = TextEditingController();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Send Feedback'),
              content: TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Enter your feedback here...', border: OutlineInputBorder()),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          if (controller.text.isEmpty) return;
                          setDialogState(() => isSending = true);
                          try {
                            await _apiService.sendFeedback({
                              'assignmentId': assignmentId,
                              'note': controller.text,
                            });
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback sent!'), backgroundColor: Colors.green));
                            }
                          } catch (e) {
                            setDialogState(() => isSending = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                            }
                          }
                        },
                  child: isSending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send'),
                )
              ],
            );
          },
        );
      },
    );
  }
}
