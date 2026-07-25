import 'package:flutter/material.dart';
import '../../dashboard/widgets/coach_home/coach_dashboard_theme.dart';
import '../../../services/api_service.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _targetGroup = 'all';
  bool _sending = false;

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final result = await _apiService.sendAdminAnnouncement(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        target: _targetGroup,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Announcement sent.'),
            backgroundColor: CoachDashboardTheme.success,
          ),
        );
      }
      _titleController.clear();
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: CoachDashboardTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      appBar: CoachDashboardTheme.coachAppBar(
        context: context,
        title: 'Send Announcements',
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: CoachDashboardTheme.cardDecoration(isDark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Target Audience', style: CoachDashboardTheme.sectionTitle(isDark)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _targetGroup,
                  decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Audience'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Users & Coaches')),
                    DropdownMenuItem(value: 'users', child: Text('Users Only')),
                    DropdownMenuItem(value: 'coaches', child: Text('Coaches Only')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _targetGroup = val);
                  },
                ),
                const SizedBox(height: 24),
                Text('Announcement', style: CoachDashboardTheme.sectionTitle(isDark)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Title'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _messageController,
                  maxLines: 5,
                  decoration: CoachDashboardTheme.fieldDecoration(isDark: isDark, label: 'Message'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Message is required' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _sendNotification,
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                    label: Text(_sending ? 'Sending...' : 'Send Announcement'),
                    style: CoachDashboardTheme.primaryButtonStyle(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
