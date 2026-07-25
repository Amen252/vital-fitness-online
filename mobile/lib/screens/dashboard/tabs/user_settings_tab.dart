import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/user_model.dart';
import '../../../services/api_service.dart';
import '../../../widgets/language_picker_sheet.dart';
import '../../../widgets/scrollable_body.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../widgets/account/change_password_dialog.dart';
import '../../support/help_support_screen.dart';
import '../../auth/coach_register_screen.dart';
import '../../auth/auth_home.dart';
import '../invite_friends_screen.dart';
import '../../../utils/share_helpers.dart';
class UserSettingsTab extends StatefulWidget {
  final User user;
  final ValueChanged<User> onUserUpdated;
  final VoidCallback onLogout;
  final ValueChanged<bool> onThemeToggle;
  final bool isDark;

  const UserSettingsTab({
    super.key,
    required this.user,
    required this.onUserUpdated,
    required this.onLogout,
    required this.onThemeToggle,
    required this.isDark,
  });

  @override
  State<UserSettingsTab> createState() => _UserSettingsTabState();
}

class _UserSettingsTabState extends State<UserSettingsTab> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _phoneController = TextEditingController();
  final _medicalController = TextEditingController();
  final List<String> _goals = [];
  bool _isSaving = false;
  bool _isLoading = true;

  bool _notifWorkout = true;
  bool _notifClass = true;
  bool _notifCoach = true;
  String? _photoUrl;
  String _gender = '';
  String _activityLevel = 'moderate';
  String? _assignedCoachName;
  late User _user;

  final List<String> _availableGoals = [
    'Weight Loss', 'Muscle Building', 'Maintain',
    'Cardio Endurance', 'Flexibility', 'Strength Training', 'Healthy Diet',
  ];

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _hydrateFromUser(_user);
    _loadNotificationPrefs();
    _refreshProfile();
  }

  Future<void> _loadNotificationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notifWorkout = prefs.getBool('notif_workout_${_user.id}') ?? true;
      _notifClass = prefs.getBool('notif_class_${_user.id}') ?? true;
      _notifCoach = prefs.getBool('notif_coach_${_user.id}') ?? true;
    });
  }

  Future<void> _saveNotificationPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${key}_${_user.id}', value);
  }

  @override
  void didUpdateWidget(covariant UserSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.profile != widget.user.profile) {
      _user = widget.user;
      _hydrateFromUser(_user);
    }
  }

  void _hydrateFromUser(User user) {
    final profile = user.profile;
    _ageController.text = profile?.age?.toString() ?? '';
    _heightController.text = profile?.heightCm?.toString() ?? '';
    _weightController.text = profile?.weightKg?.toString() ?? '';
    _phoneController.text = user.phone ?? profile?.phone ?? '';
    _medicalController.text = profile?.medicalNotes ?? '';
    _gender = profile?.gender ?? '';
    _activityLevel = profile?.activityLevel?.isNotEmpty == true
        ? profile!.activityLevel!
        : 'moderate';
    _assignedCoachName = profile?.assignedCoachName;
    _photoUrl = profile?.photoUrl;
    _goals
      ..clear()
      ..addAll(_mapGoalsForUi(profile?.goals ?? const [], profile?.fitnessGoal));
  }

  List<String> _mapGoalsForUi(List<String> goals, String? fitnessGoal) {
    String labelFor(String raw) {
      final v = raw.trim().toLowerCase();
      if (v == 'lose_weight' || v.contains('weight loss') || v.contains('lose weight')) {
        return 'Weight Loss';
      }
      if (v == 'gain_muscle' || v.contains('muscle')) return 'Muscle Building';
      if (v == 'maintain' || v.contains('maintain')) return 'Maintain';
      if (v == 'other' || v.contains('general')) return 'Healthy Diet';
      for (final option in _availableGoals) {
        if (option.toLowerCase() == v) return option;
      }
      return raw;
    }

    final mapped = goals.map(labelFor).where((g) => g.isNotEmpty).toList();
    if (mapped.isEmpty && fitnessGoal != null && fitnessGoal.isNotEmpty) {
      mapped.add(labelFor(fitnessGoal));
    }
    return mapped.toSet().toList();
  }

  Future<void> _refreshProfile() async {
    setState(() => _isLoading = true);
    try {
      final fresh = await _apiService.getMe();
      if (!mounted) return;
      if (fresh != null && fresh.id == widget.user.id) {
        _user = fresh;
        _hydrateFromUser(fresh);
        widget.onUserUpdated(fresh);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onPhotoChanged(String? newUrl) {
    setState(() => _photoUrl = newUrl);
    final updatedProfile = _user.profile?.copyWith(photoUrl: newUrl) ??
        Profile(goals: const [], photoUrl: newUrl);
    final updated = _user.copyWith(profile: updatedProfile);
    _user = updated;
    widget.onUserUpdated(updated);
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _phoneController.dispose();
    _medicalController.dispose();
    super.dispose();
  }

  void _toggleGoal(String goal) {
    setState(() {
      if (_goals.contains(goal)) {
        _goals.remove(goal);
      } else {
        _goals.add(goal);
      }
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final updatedProfile = await _apiService.updateProfile(
        age: int.tryParse(_ageController.text),
        heightCm: double.tryParse(_heightController.text),
        weightKg: double.tryParse(_weightController.text),
        goals: _goals,
        gender: _gender,
        activityLevel: _activityLevel,
        medicalNotes: _medicalController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      final updatedUser = _user.copyWith(
        phone: _phoneController.text.trim(),
        profile: updatedProfile.copyWith(
          assignedCoachName: _assignedCoachName,
          photoUrl: _photoUrl ?? updatedProfile.photoUrl,
        ),
      );
      _user = updatedUser;
      _hydrateFromUser(updatedUser);
      widget.onUserUpdated(updatedUser);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).profileUpdated), backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ApiService.friendlyError(e)), backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      appBar: CoachDashboardTheme.coachAppBar(
        context: context,
        title: l10n.settingsAndProfile,
      ),
      body: SingleChildScrollView(
        physics: dashboardScrollPhysics,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            
            // Profile Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181B24) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                ProfileAvatar(
                  name: _user.name,
                  photoUrl: _photoUrl,
                  radius: 36,
                  editable: true,
                  backgroundColor: CoachDashboardTheme.primary,
                  onPhotoChanged: _onPhotoChanged,
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(_user.email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  if ((_phoneController.text).isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(_phoneController.text, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                  if (_user.isClient) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF00D4AA).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Text('CLIENT', style: TextStyle(color: Color(0xFF00D4AA), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  if (_user.hasPendingCoachApplication) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: CoachDashboardTheme.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'COACH APPLICATION PENDING',
                        style: TextStyle(
                          color: CoachDashboardTheme.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ])),
                IconButton(
                  tooltip: 'Refresh profile',
                  onPressed: _isLoading ? null : _refreshProfile,
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded),
                ),
              ]),
            ),
            if (_assignedCoachName != null && _assignedCoachName!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF181B24) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CoachDashboardTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school_outlined, color: CoachDashboardTheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Assigned coach', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                          Text(_assignedCoachName!, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // App Settings
            Text(l10n.appSettings, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            _buildSettingsGroup(isDark, [
              SwitchListTile(
                title: Text(l10n.darkMode),
                secondary: const Icon(Icons.dark_mode_rounded, color: CoachDashboardTheme.primary),
                value: widget.isDark,
                onChanged: widget.onThemeToggle,
                activeColor: CoachDashboardTheme.primary,
              ),
              const Divider(height: 1),
              ListTile(
                title: Text(l10n.language),
                subtitle: Text(l10n.languageLabel(localeCode)),
                leading: const Icon(Icons.language_rounded, color: Colors.orange),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: () => showLanguagePicker(context),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Invite friends'),
                subtitle: const Text('Share your personal invite link'),
                leading: const Icon(Icons.person_add_alt_1_rounded, color: CoachDashboardTheme.primary),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InviteFriendsScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Share weekly win'),
                subtitle: const Text('Create a public progress card'),
                leading: const Icon(Icons.ios_share_rounded, color: Colors.teal),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: () => shareVitalCard(context, type: 'weekly'),
              ),
            ]),
            if (_user.isClient && !_user.hasPendingCoachApplication) ...[
              const SizedBox(height: 24),
              Text('Become a coach', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 12),
              _buildSettingsGroup(isDark, [
                ListTile(
                  title: const Text('Apply to become a coach'),
                  subtitle: Text(
                    _user.hasRejectedCoachApplication
                        ? 'Your last application was rejected. You can reapply.'
                        : 'Submit an application for admin review (same as web).',
                  ),
                  leading: const Icon(Icons.school_outlined, color: CoachDashboardTheme.primary),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CoachRegisterScreen(existingUser: _user),
                      ),
                    );
                    if (!mounted) return;
                    try {
                      final refreshed = await _apiService.getMe();
                      if (!mounted || refreshed == null) return;
                      if (refreshed.hasPendingCoachApplication ||
                          refreshed.isCoach) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => AuthHome(user: refreshed),
                          ),
                          (_) => false,
                        );
                        return;
                      }
                      widget.onUserUpdated(refreshed);
                    } catch (_) {}
                  },
                ),
              ]),
            ],
            const SizedBox(height: 24),

            // Notifications
            Text(l10n.notifications, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            _buildSettingsGroup(isDark, [
              SwitchListTile(
                title: Text(l10n.workoutReminders),
                secondary: const Icon(Icons.fitness_center_rounded, color: Color(0xFFFF6B6B)),
                value: _notifWorkout,
                onChanged: (v) {
                  setState(() => _notifWorkout = v);
                  _saveNotificationPref('notif_workout', v);
                },
                activeColor: const Color(0xFF00D4AA),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(l10n.classUpdates),
                secondary: const Icon(Icons.event_rounded, color: Colors.blue),
                value: _notifClass,
                onChanged: (v) {
                  setState(() => _notifClass = v);
                  _saveNotificationPref('notif_class', v);
                },
                activeColor: const Color(0xFF00D4AA),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(l10n.coachMessages),
                secondary: const Icon(Icons.chat_bubble_rounded, color: Colors.purple),
                value: _notifCoach,
                onChanged: (v) {
                  setState(() => _notifCoach = v);
                  _saveNotificationPref('notif_coach', v);
                },
                activeColor: const Color(0xFF00D4AA),
              ),
            ]),
            const SizedBox(height: 24),

            _buildPersonalInformationSection(isDark, l10n),
            const SizedBox(height: 24),

            // Goals
            Text(l10n.fitnessGoals, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            _buildSettingsGroup(isDark, [
              ..._availableGoals.asMap().entries.map((entry) {
                final i = entry.key;
                final g = entry.value;
                final sel = _goals.contains(g);
                return Column(
                  children: [
                    CheckboxListTile(
                      value: sel,
                      onChanged: (_) => _toggleGoal(g),
                      activeColor: CoachDashboardTheme.primary,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(g, style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    if (i < _availableGoals.length - 1) const Divider(height: 1, indent: 56),
                  ],
                );
              }),
            ]),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: CoachDashboardTheme.primary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(l10n.saveProfileChanges, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 32),

            Text(l10n.account, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            _buildSettingsGroup(isDark, [
              ListTile(
                leading: const Icon(Icons.lock_outline_rounded, color: CoachDashboardTheme.primary),
                title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Update your account password'),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: () => showChangePasswordDialog(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded, color: CoachDashboardTheme.primary),
                title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('FAQs and contact support'),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
                },
              ),
            ]),
            const SizedBox(height: 32),

            // Logout
            OutlinedButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: Text(l10n.signOut, style: const TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF6B6B),
                side: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181B24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  double? get _computedBmi {
    final heightCm = double.tryParse(_heightController.text);
    final weightKg = double.tryParse(_weightController.text);
    if (heightCm == null || weightKg == null || heightCm <= 0) return null;
    final heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  Widget _buildPersonalInformationSection(bool isDark, AppLocalizations l10n) {
    final bmi = _computedBmi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: CoachDashboardTheme.headerGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.personalInformation, style: CoachDashboardTheme.sectionTitle(isDark)),
                  const SizedBox(height: 2),
                  Text(
                    l10n.personalInformationSubtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          decoration: CoachDashboardTheme.cardDecoration(isDark),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  _metricInputTile(
                    isDark: isDark,
                    icon: Icons.cake_outlined,
                    color: const Color(0xFF8B5CF6),
                    label: l10n.age,
                    unit: l10n.years,
                    controller: _ageController,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = int.tryParse(v);
                      if (n == null || n < 1 || n > 120) return '1–120';
                      return null;
                    },
                  ),
                  const SizedBox(width: 10),
                  _metricInputTile(
                    isDark: isDark,
                    icon: Icons.straighten_rounded,
                    color: CoachDashboardTheme.accent,
                    label: l10n.heightCm,
                    unit: 'cm',
                    controller: _heightController,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = double.tryParse(v);
                      if (n == null || n < 50 || n > 250) return '50–250';
                      return null;
                    },
                  ),
                  const SizedBox(width: 10),
                  _metricInputTile(
                    isDark: isDark,
                    icon: Icons.monitor_weight_outlined,
                    color: CoachDashboardTheme.success,
                    label: l10n.weightKg,
                    unit: 'kg',
                    controller: _weightController,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = double.tryParse(v);
                      if (n == null || n < 20 || n > 300) return '20–300';
                      return null;
                    },
                  ),
                ],
              ),
              if (bmi != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F1117) : const Color(0xFFF3F4F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.insights_rounded, size: 20, color: _bmiColor(bmi)),
                      const SizedBox(width: 10),
                      Text(
                        l10n.bmi,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : CoachDashboardTheme.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        bmi.toStringAsFixed(1),
                        style: CoachDashboardTheme.metricValue(_bmiColor(bmi)).copyWith(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _bmiColor(bmi).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _bmiLabel(bmi),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _bmiColor(bmi),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: (_gender == 'Female' || _gender == 'Male' || _gender == 'Other') ? _gender : null,
                decoration: InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: const Icon(Icons.wc_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) => setState(() => _gender = value ?? ''),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: ['sedentary', 'moderate', 'active'].contains(_activityLevel) ? _activityLevel : 'moderate',
                decoration: InputDecoration(
                  labelText: 'Activity level',
                  prefixIcon: const Icon(Icons.directions_run_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'sedentary', child: Text('Sedentary')),
                  DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                ],
                onChanged: (value) => setState(() => _activityLevel = value ?? 'moderate'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _medicalController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Medical notes',
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.medical_information_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricInputTile({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String label,
    required String unit,
    required TextEditingController controller,
    required String? Function(String?)? validator,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1117) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: CoachDashboardTheme.metricLabel(isDark).copyWith(fontSize: 11),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : CoachDashboardTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '—',
                hintStyle: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white24 : CoachDashboardTheme.textSecondary.withValues(alpha: 0.35),
                ),
                suffixText: unit,
                suffixStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : CoachDashboardTheme.textSecondary,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                errorStyle: const TextStyle(fontSize: 10, height: 1),
              ),
              validator: validator,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return CoachDashboardTheme.accent;
    if (bmi < 25) return CoachDashboardTheme.success;
    if (bmi < 30) return CoachDashboardTheme.warning;
    return CoachDashboardTheme.danger;
  }

  String _bmiLabel(double bmi) {
    if (bmi < 18.5) return 'Under';
    if (bmi < 25) return 'Healthy';
    if (bmi < 30) return 'Over';
    return 'High';
  }
}
