import 'package:flutter/material.dart';
import 'widgets/coach_home/coach_dashboard_theme.dart';
import '../../services/api_service.dart';
import '../../utils/share_helpers.dart';

class InviteFriendsScreen extends StatefulWidget {
  const InviteFriendsScreen({super.key});

  @override
  State<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _invite;

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
      final invite = await _api.getMyInvite();
      if (!mounted) return;
      setState(() {
        _invite = invite;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiService.friendlyError(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final code = _invite?['code']?.toString() ?? '';
    final url = _invite?['url']?.toString() ?? '';
    final uses = _invite?['uses'] ?? 0;

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      appBar: CoachDashboardTheme.coachAppBar(
        context: context,
        title: 'Invite friends',
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CoachDashboardTheme.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: CoachDashboardTheme.headerGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 32),
                          SizedBox(height: 12),
                          Text(
                            'Invite friends to Vital Fitness',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Share your personal link. When they join, you’ll get a notification.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: CoachDashboardTheme.cardDecoration(isDark),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your invite code', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Text(
                            code,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                              color: CoachDashboardTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SelectableText(url, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 12),
                          Text('$uses friend${uses == 1 ? '' : 's'} joined with your code'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: url.isEmpty ? null : () => copyText(context, url),
                                  icon: const Icon(Icons.copy_rounded),
                                  label: const Text('Copy'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => shareInviteLink(context),
                                  icon: const Icon(Icons.ios_share_rounded),
                                  label: const Text('Share'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: CoachDashboardTheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: CoachDashboardTheme.cardDecoration(isDark),
                      child: const Text(
                        'You can also share progress and weekly wins from Home and Progress. Workout completions will offer a share prompt.',
                        style: TextStyle(height: 1.4),
                      ),
                    ),
                  ],
                ),
    );
  }
}
