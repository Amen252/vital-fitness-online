import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/scrollable_body.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';

class CoachRequestsPanel extends StatefulWidget {
  final VoidCallback? onRequestHandled;

  const CoachRequestsPanel({super.key, this.onRequestHandled});

  @override
  State<CoachRequestsPanel> createState() => _CoachRequestsPanelState();
}

class _CoachRequestsPanelState extends State<CoachRequestsPanel> {
  final ApiService _apiService = ApiService();
  List<dynamic> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _busyRequestId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final showFullLoader = _requests.isEmpty;
    setState(() {
      if (showFullLoader) _isLoading = true;
      _errorMessage = null;
    });
    try {
      final requests = await _apiService.getCoachRequests();
      if (mounted) {
        setState(() {
          _requests = List<dynamic>.from(requests);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approve(String requestId, String memberName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Approve member?'),
          content: Text(
            'Approve $memberName as your client? You can add them to a class afterwards from Classes.',
            style: TextStyle(height: 1.4, color: isDark ? Colors.white70 : null),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: CoachDashboardTheme.primaryButtonStyle(),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _busyRequestId = requestId);
    try {
      await _apiService.approveCoachRequest(requestId);
      if (mounted) {
        setState(() {
          _busyRequestId = null;
          _requests = _requests
              .where((r) => r is! Map || r['_id']?.toString() != requestId)
              .toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$memberName approved. You can now add them to a class.'),
            backgroundColor: CoachDashboardTheme.success,
          ),
        );
      }
      _load();
      widget.onRequestHandled?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _busyRequestId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted && _busyRequestId == requestId) {
        setState(() => _busyRequestId = null);
      }
    }
  }

  Future<void> _reject(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject request?'),
        content: const Text('Reject this coaching request? The member will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: CoachDashboardTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyRequestId = requestId);
    try {
      await _apiService.rejectCoachRequest(requestId);
      if (mounted) {
        setState(() {
          _busyRequestId = null;
          _requests = _requests
              .where((r) => r is! Map || r['_id']?.toString() != requestId)
              .toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request rejected.'), backgroundColor: CoachDashboardTheme.warning),
        );
      }
      _load();
      widget.onRequestHandled?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _busyRequestId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted && _busyRequestId == requestId) {
        setState(() => _busyRequestId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: CoachDashboardTheme.primary));
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: CoachDashboardTheme.danger)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_requests.isEmpty) {
      return CoachDashboardTheme.emptyState(
        icon: Icons.inbox_rounded,
        message: 'No pending requests.',
        isDark: isDark,
      );
    }

    return ListView.builder(
      physics: dashboardScrollPhysics,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final request = _requests[index] as Map<String, dynamic>;
        final requestId = request['_id']?.toString() ?? '';
        final user = request['user'] as Map<String, dynamic>? ?? {};
        final name = ApiService.displayName(user, fallback: 'Member');
        return _RequestCard(
          request: request,
          isDark: isDark,
          isBusy: _busyRequestId == requestId,
          onApprove: () => _approve(requestId, name),
          onReject: () => _reject(requestId),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final bool isDark;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard({
    required this.request,
    required this.isDark,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final user = request['user'] as Map<String, dynamic>? ?? {};
    final name = ApiService.displayName(user, fallback: 'Member');
    final email = ApiService.displayIdentity(user);
    final message = request['message'] as String? ?? '';
    final profile = user['profile'] as Map<String, dynamic>? ?? {};
    final goals = profile['goals'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CoachDashboardTheme.avatarBox(
                initial: name.isNotEmpty ? name[0].toUpperCase() : 'U',
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pending approval',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CoachDashboardTheme.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (goals.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Fitness goals', style: CoachDashboardTheme.sectionLabel(isDark)),
            const SizedBox(height: 4),
            Text(goals.take(3).join(' · '), style: const TextStyle(fontSize: 13, height: 1.35)),
          ],
          const SizedBox(height: 12),
          Text('Message from member', style: CoachDashboardTheme.sectionLabel(isDark)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1117) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Text(
              message.isNotEmpty ? message : 'No message provided.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontStyle: message.isEmpty ? FontStyle.italic : FontStyle.normal,
                color: message.isEmpty
                    ? (isDark ? Colors.white38 : CoachDashboardTheme.textSecondary)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Approve first, then add this member to a class from the Classes tab.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : onReject,
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: CoachDashboardTheme.primaryButtonStyle(),
                  onPressed: isBusy ? null : onApprove,
                  child: isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
