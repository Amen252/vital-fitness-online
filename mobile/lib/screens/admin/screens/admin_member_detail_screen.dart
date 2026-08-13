import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../widgets/scrollable_body.dart';
import '../../dashboard/widgets/coach_home/coach_dashboard_theme.dart';
import '../widgets/admin_management_widgets.dart';
import '../../../widgets/silent_refresh.dart';

class AdminMemberDetailScreen extends StatefulWidget {
  final String userId;
  final String? initialName;

  const AdminMemberDetailScreen({
    super.key,
    required this.userId,
    this.initialName,
  });

  @override
  State<AdminMemberDetailScreen> createState() => _AdminMemberDetailScreenState();
}

class _AdminMemberDetailScreenState extends State<AdminMemberDetailScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getAdminUserDetail(widget.userId);
      if (mounted) {
        setState(() {
          _detail = data;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiService.friendlyError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fitnessGoalLabel(String? goal) {
    switch (goal) {
      case 'lose_weight':
        return 'Lose weight';
      case 'gain_muscle':
        return 'Gain muscle';
      case 'maintain':
        return 'Maintain';
      case 'other':
        return 'General';
      default:
        return goal ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.initialName ?? 'Member Details';

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      appBar: AppBar(
        title: Text(title, style: CoachDashboardTheme.appBarTitle(isDark)),
        backgroundColor: CoachDashboardTheme.homeBackground(isDark),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: CoachDashboardTheme.danger)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : SilentRefreshIndicator(
                  onRefresh: _load,
                  color: CoachDashboardTheme.primary,
                  child: ScrollableBody(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    child: _buildContent(isDark),
                  ),
                ),
    );
  }

  Widget _buildContent(bool isDark) {
    final user = Map<String, dynamic>.from(_detail!['user'] as Map);
    final clientData = Map<String, dynamic>.from(user['clientData'] as Map? ?? {});
    final name = (user['full_name'] ?? user['name'] ?? user['username'] ?? 'Member').toString();
    final username = (user['username'] ?? '').toString();
    final phone = (user['phone'] ?? '').toString();
    final gender = (clientData['gender'] ?? '').toString();
    final age = clientData['age'];
    final height = clientData['height'];
    final weight = clientData['weight'];
    final fitnessGoal = _fitnessGoalLabel(clientData['fitness_goal']?.toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: CoachDashboardTheme.cardDecoration(isDark),
          child: Row(
            children: [
              CoachDashboardTheme.avatarBox(
                initial: name.isNotEmpty ? name[0].toUpperCase() : '?',
                size: 56,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    if (username.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '@$username',
                        style: TextStyle(color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'View-only registration details from the app.',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        AdminDetailSection(
          isDark: isDark,
          title: 'Registration details',
          children: [
            AdminDetailRow(isDark: isDark, label: 'Full name', value: name),
            AdminDetailRow(isDark: isDark, label: 'Username', value: username),
            AdminDetailRow(isDark: isDark, label: 'Phone', value: phone),
            AdminDetailRow(isDark: isDark, label: 'Gender', value: gender),
            AdminDetailRow(isDark: isDark, label: 'Age', value: age?.toString() ?? ''),
            AdminDetailRow(
              isDark: isDark,
              label: 'Height',
              value: height != null ? '$height cm' : '',
            ),
            AdminDetailRow(
              isDark: isDark,
              label: 'Weight',
              value: weight != null ? '$weight kg' : '',
            ),
            AdminDetailRow(isDark: isDark, label: 'Fitness goal', value: fitnessGoal),
            AdminDetailRow(
              isDark: isDark,
              label: 'Registered',
              value: formatAdminDate(user['createdAt']),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _confirmDelete(name),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete User'),
            style: OutlinedButton.styleFrom(
              foregroundColor: CoachDashboardTheme.danger,
              side: BorderSide(color: CoachDashboardTheme.danger.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete this user?\n\nPermanently delete $name? This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: CoachDashboardTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.deleteUser(widget.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name has been deleted.'),
          backgroundColor: CoachDashboardTheme.success,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiService.friendlyError(e)), backgroundColor: CoachDashboardTheme.danger),
      );
    }
  }
}
