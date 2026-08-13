import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../utils/password_utils.dart';
import '../dashboard/widgets/coach_home/coach_dashboard_theme.dart';
import 'auth_home.dart';

/// Forced password change — matches web `/change-password` SessionGuard.
class ForceChangePasswordScreen extends StatefulWidget {
  final User user;
  final int? memberInitialTabIndex;

  const ForceChangePasswordScreen({
    super.key,
    required this.user,
    this.memberInitialTabIndex,
  });

  @override
  State<ForceChangePasswordScreen> createState() =>
      _ForceChangePasswordScreenState();
}

class _ForceChangePasswordScreenState extends State<ForceChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await _api.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AuthHome(
            user: widget.user.copyWith(mustChangePassword: false),
            memberInitialTabIndex: widget.memberInitialTabIndex,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ApiService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: CoachDashboardTheme.headerGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: isDark ? const Color(0xFF181B24) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Update your password',
                            style: CoachDashboardTheme.sectionTitle(isDark),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You must set a new password before continuing.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white60
                                  : CoachDashboardTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: CoachDashboardTheme.danger
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: CoachDashboardTheme.danger,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _field(
                            isDark: isDark,
                            controller: _currentController,
                            label: 'Current password',
                            visible: _showCurrent,
                            onToggle: () =>
                                setState(() => _showCurrent = !_showCurrent),
                            validator: (v) =>
                                v == null || v.isEmpty
                                    ? 'Enter your current password'
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            isDark: isDark,
                            controller: _newController,
                            label: 'New password',
                            visible: _showNew,
                            onToggle: () =>
                                setState(() => _showNew = !_showNew),
                            validator: PasswordUtils.validatePassword,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            isDark: isDark,
                            controller: _confirmController,
                            label: 'Confirm new password',
                            visible: _showConfirm,
                            onToggle: () =>
                                setState(() => _showConfirm = !_showConfirm),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Confirm your new password';
                              }
                              if (v != _newController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            style: CoachDashboardTheme.primaryButtonStyle(),
                            onPressed: _isSaving ? null : _submit,
                            child: const Text('Continue'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required bool isDark,
    required TextEditingController controller,
    required String label,
    required bool visible,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      validator: validator,
      style: TextStyle(
        color: isDark ? Colors.white : CoachDashboardTheme.textPrimary,
      ),
      decoration: CoachDashboardTheme.fieldDecoration(
        isDark: isDark,
        label: label,
        prefixIcon: Icons.lock_outline_rounded,
      ).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
