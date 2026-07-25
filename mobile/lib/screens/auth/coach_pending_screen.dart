import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../widgets/scrollable_body.dart';
import '../dashboard/coach_dashboard_screen.dart';
import '../dashboard/widgets/coach_home/coach_dashboard_theme.dart';
import 'auth_home.dart';
import 'login_screen.dart';

class CoachPendingScreen extends StatefulWidget {
  final User user;

  const CoachPendingScreen({super.key, required this.user});

  @override
  State<CoachPendingScreen> createState() => _CoachPendingScreenState();
}

class _CoachPendingScreenState extends State<CoachPendingScreen> {
  final ApiService _apiService = ApiService();
  bool _isRefreshing = false;
  String? _errorMessage;
  User? _approvedUser;
  late User _currentUser;
  Timer? _pollTimer;

  bool get _isApproved => _approvedUser?.role == 'coach';

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _refreshStatus(silent: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_isApproved && mounted) _refreshStatus(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _openCoachDashboard() {
    final user = _approvedUser;
    if (user == null) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => CoachDashboardScreen(coachUser: user)),
      (_) => false,
    );
  }

  Future<void> _refreshStatus({bool silent = false}) async {
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      final user = await _apiService.getMe();
      if (!mounted) return;

      if (user == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
        return;
      }

      if (user.role == 'coach') {
        setState(() {
          _approvedUser = user;
          _currentUser = user;
          _isRefreshing = false;
          _errorMessage = null;
        });
        return;
      }

      if (user.coachApplicationStatus != 'pending') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => AuthHome(user: user)),
        );
        return;
      }

      setState(() {
        _currentUser = user;
        _approvedUser = null;
        _isRefreshing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ApiService.friendlyError(e);
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await _apiService.clearAuth();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String _joinList(List<String> values) =>
      values.map((v) => v.trim()).where((v) => v.isNotEmpty).join(', ');

  String _formatDayAvailability(List<dynamic> days) {
    final parts = <String>[];
    for (final raw in days) {
      if (raw is! Map) continue;
      final day = raw['day']?.toString() ?? '';
      if (day.isEmpty) continue;
      final start = raw['start']?.toString() ?? '';
      final end = raw['end']?.toString() ?? '';
      parts.add('$day ${start.isNotEmpty || end.isNotEmpty ? '$start–$end' : ''}'.trim());
    }
    return parts.join(', ');
  }

  Widget _profileRow(String label, String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(text, style: const TextStyle(fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }

  Widget _submittedProfileCard(bool isDark) {
    final profile = _currentUser.profile;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your submitted profile', style: CoachDashboardTheme.sectionLabel(isDark)),
          const SizedBox(height: 10),
          _profileRow('Name', _currentUser.name),
          _profileRow('Email', _currentUser.email),
          _profileRow('Phone', profile?.phone),
          _profileRow('Location', profile?.location),
          _profileRow('Age', profile?.age?.toString()),
          _profileRow('Years experience', profile?.yearsExperience?.toString()),
          _profileRow('Specialization', _joinList(profile?.specialization ?? const [])),
          _profileRow('Certifications', _joinList(profile?.certifications ?? const [])),
          _profileRow('Working days', _joinList(profile?.workingDays ?? const [])),
          _profileRow('Appointment days', _joinList(profile?.appointmentDays ?? const [])),
          _profileRow(
            'Appointment duration',
            profile?.appointmentDurationMinutes != null
                ? '${profile!.appointmentDurationMinutes} min'
                : null,
          ),
          _profileRow(
            'Day availability',
            _formatDayAvailability(profile?.dayAvailability ?? const []),
          ),
          _profileRow('Experience', profile?.experience),
          _profileRow('Bio', profile?.bio),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: dashboardScrollPhysics,
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: (_isApproved ? CoachDashboardTheme.success : CoachDashboardTheme.warning)
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isApproved ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                      size: 56,
                      color: _isApproved ? CoachDashboardTheme.success : CoachDashboardTheme.warning,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isApproved ? 'Application Approved!' : 'Application Under Review',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isApproved
                        ? 'Congratulations ${_currentUser.name}! Your coach application has been approved. '
                            'Tap the button below to open your coach dashboard.'
                        : 'Hi ${_currentUser.name}, your coach application has been submitted. '
                            'Review your profile details below while an admin decides.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: isDark ? Colors.white70 : CoachDashboardTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!_isApproved) ...[
                    _submittedProfileCard(isDark),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: CoachDashboardTheme.cardDecoration(isDark),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isApproved ? 'You are ready to coach' : 'What happens next?',
                          style: CoachDashboardTheme.sectionLabel(isDark),
                        ),
                        const SizedBox(height: 8),
                        if (_isApproved) ...[
                          _step('1', 'Your profile is now visible to app members'),
                          _step('2', 'Open your coach dashboard to manage clients and classes'),
                          _step('3', 'Check notifications for any updates from admin'),
                        ] else ...[
                          _step('1', 'Admin reviews your credentials and experience'),
                          _step('2', 'You receive an in-app and email notification with the decision'),
                          _step('3', 'Once approved, an "Open Coach Dashboard" button will appear here'),
                        ],
                      ],
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: CoachDashboardTheme.danger),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_isApproved) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: CoachDashboardTheme.primaryButtonStyle(),
                        onPressed: _openCoachDashboard,
                        icon: const Icon(Icons.dashboard_rounded, color: Colors.white),
                        label: const Text('Open Coach Dashboard'),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: CoachDashboardTheme.primaryButtonStyle(),
                        onPressed: _isRefreshing ? null : () => _refreshStatus(),
                        child: _isRefreshing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Check Status'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _logout,
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _step(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number.', style: const TextStyle(fontWeight: FontWeight.bold, color: CoachDashboardTheme.primary)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
