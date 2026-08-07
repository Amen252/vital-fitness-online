import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/coach_application_prefs.dart';
import '../../widgets/scrollable_body.dart';
import '../dashboard/widgets/coach_home/coach_dashboard_theme.dart';
import 'auth_home.dart';
import 'coach_register_screen.dart';
import 'login_screen.dart';

class CoachRejectedScreen extends StatefulWidget {
  final User user;

  const CoachRejectedScreen({super.key, required this.user});

  @override
  State<CoachRejectedScreen> createState() => _CoachRejectedScreenState();
}

class _CoachRejectedScreenState extends State<CoachRejectedScreen> {
  final ApiService _apiService = ApiService();
  bool _isRefreshing = false;
  String? _errorMessage;
  late User _currentUser;
  DateTime? _lastCheckedAt;
  String? _rejectionReason;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadRejectionReason();
  }

  Future<void> _loadRejectionReason() async {
    try {
      final application = await _apiService.getMyCoachApplication();
      final reason = application?['rejectionReason']?.toString().trim() ?? '';
      if (!mounted) return;
      setState(() => _rejectionReason = reason.isEmpty ? null : reason);
    } catch (_) {}
  }

  Future<User?> _fetchLatestUser() async {
    final user = await _apiService.getMe();
    if (user == null) return null;

    try {
      final application = await _apiService.getMyCoachApplication();
      if (application == null) return user;

      final appStatus = application['status']?.toString();
      final reviewedRaw = application['reviewedAt']?.toString();
      final reviewedAt = reviewedRaw != null ? DateTime.tryParse(reviewedRaw) : null;

      return user.copyWith(
        coachApplicationStatus: appStatus ?? user.coachApplicationStatus,
        coachApplicationReviewedAt: reviewedAt ?? user.coachApplicationReviewedAt,
      );
    } catch (_) {
      return user;
    }
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      final user = await _fetchLatestUser();
      if (!mounted) return;

      if (user == null) {
        setState(() {
          _isRefreshing = false;
          _errorMessage = 'Could not refresh status. Check your connection and try again.';
        });
        return;
      }

      _lastCheckedAt = DateTime.now();

      if (user.hasApprovedCoachApplication || user.hasPendingCoachApplication) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => AuthHome(user: user)),
        );
        return;
      }

      if (!user.hasRejectedCoachApplication) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => AuthHome(user: user)),
        );
        return;
      }

      setState(() {
        _currentUser = user;
        _isRefreshing = false;
      });
      await _loadRejectionReason();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status: Rejected — you can update your details and reapply.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ApiService.friendlyError(e);
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _continueAsMember() async {
    await CoachApplicationPrefs.dismissRejection(
      userId: _currentUser.id,
      reviewedAt: _currentUser.coachApplicationReviewedAt,
    );
    if (!mounted) return;
    // Stay on the client (member) shell — same as web member experience.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AuthHome(user: _currentUser),
      ),
    );
  }

  Future<void> _reapply() async {
    await CoachApplicationPrefs.clearRejectionDismissed(widget.user.id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CoachRegisterScreen(existingUser: _currentUser),
      ),
    );
    if (!mounted) return;
    await _refreshStatus();
  }

  Future<void> _viewRegistration() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CoachRegisterScreen(
          existingUser: _currentUser,
          viewOnly: true,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await _apiService.clearAuth();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
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
                      color: CoachDashboardTheme.danger.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cancel_outlined,
                      size: 56,
                      color: CoachDashboardTheme.danger,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Application Not Approved',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: CoachDashboardTheme.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CoachDashboardTheme.danger.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.cancel_outlined, color: CoachDashboardTheme.danger, size: 22),
                            SizedBox(width: 10),
                            Text(
                              'Application status: Rejected',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: CoachDashboardTheme.danger,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        if (_lastCheckedAt != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Last checked ${DateFormat('MMM d, h:mm a').format(_lastCheckedAt!.toLocal())}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hi ${_currentUser.name}, thank you for applying to coach at VitalFitness. '
                    'After reviewing your submission, we are unable to approve your application at this time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: isDark ? Colors.white70 : CoachDashboardTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a confirmation email to ${_currentUser.email}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                  ),
                  if ((_rejectionReason ?? '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: CoachDashboardTheme.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CoachDashboardTheme.danger.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rejection reason',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: CoachDashboardTheme.danger,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(_rejectionReason!, style: const TextStyle(height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: CoachDashboardTheme.cardDecoration(isDark),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('What you can do next', style: CoachDashboardTheme.sectionLabel(isDark)),
                        const SizedBox(height: 8),
                        _step('1', 'Review your certifications, bio, and experience details'),
                        _step('2', 'Update your information and submit a new application'),
                        _step('3', 'Or continue using VitalFitness as a regular member'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: CoachDashboardTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CoachDashboardTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Text(
                      'Tip: Strong applications include clear certifications, specific specializations, and detailed coaching experience.',
                      style: TextStyle(fontSize: 13, height: 1.4),
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
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: CoachDashboardTheme.primaryButtonStyle(),
                      onPressed: _isRefreshing ? null : _reapply,
                      child: const Text('Update & Reapply'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isRefreshing ? null : _viewRegistration,
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('View Registration'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isRefreshing ? null : _continueAsMember,
                      child: const Text('Continue as Member'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _isRefreshing ? null : _refreshStatus,
                      child: _isRefreshing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Check Status'),
                    ),
                  ),
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
          Text(
            '$number.',
            style: const TextStyle(fontWeight: FontWeight.bold, color: CoachDashboardTheme.primary),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
