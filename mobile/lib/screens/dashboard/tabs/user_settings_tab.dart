import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../invite_friends_screen.dart';
import '../../../utils/share_helpers.dart';

/// Matches [pubspec.yaml] version — display only, not user/API data.
const String kAppVersionLabel = '1.0.0+1';

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
  State<UserSettingsTab> createState() => UserSettingsTabState();
}

class UserSettingsTabState extends State<UserSettingsTab> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  /// Called when the Settings tab is selected so the profile header is visible.
  void scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _phoneController = TextEditingController();
  final _medicalController = TextEditingController();
  final _waterGoalController = TextEditingController();
  final _calorieGoalController = TextEditingController();

  final List<String> _goals = [];
  bool _isSaving = false;
  bool _isLoading = true;
  bool _profileExpanded = false;

  bool _notifWorkout = true;
  bool _notifClass = true;
  bool _notifCoach = true;
  bool _emailDigest = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _unitSystem = 'metric'; // metric | imperial

  String? _photoUrl;
  String _gender = '';
  String _activityLevel = 'moderate';
  String? _assignedCoachName;
  late User _user;

  final List<String> _availableGoals = [
    'Weight Loss',
    'Muscle Building',
    'Maintain',
    'Cardio Endurance',
    'Flexibility',
    'Strength Training',
    'Healthy Diet',
  ];

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _hydrateFromUser(_user);
    _loadLocalPrefs();
    _refreshProfile();
  }

  Future<void> _loadLocalPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notifWorkout = prefs.getBool('notif_workout_${_user.id}') ?? true;
      _notifClass = prefs.getBool('notif_class_${_user.id}') ?? true;
      _notifCoach = prefs.getBool('notif_coach_${_user.id}') ?? true;
      _emailDigest = prefs.getBool('email_digest_${_user.id}') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled_${_user.id}') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled_${_user.id}') ?? true;
      _unitSystem = prefs.getString('unit_system_${_user.id}') ?? 'metric';
      final waterGoal = prefs.getInt('water_goal_ml_${_user.id}');
      final calorieGoal = prefs.getInt('calorie_goal_${_user.id}');
      if (waterGoal != null) {
        _waterGoalController.text = waterGoal.toString();
      }
      if (calorieGoal != null) {
        _calorieGoalController.text = calorieGoal.toString();
      }
    });
  }

  Future<void> _savePrefBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${key}_${_user.id}', value);
  }

  Future<void> _savePrefString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${key}_${_user.id}', value);
  }

  Future<void> _savePrefInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${key}_${_user.id}', value);
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.friendlyError(e)),
            backgroundColor: CoachDashboardTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
    _scrollController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _phoneController.dispose();
    _medicalController.dispose();
    _waterGoalController.dispose();
    _calorieGoalController.dispose();
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
    if (!_formKey.currentState!.validate()) {
      setState(() => _profileExpanded = true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final waterGoal = int.tryParse(_waterGoalController.text.trim());
      final calorieGoal = int.tryParse(_calorieGoalController.text.trim());
      if (waterGoal != null && waterGoal > 0) {
        await _savePrefInt('water_goal_ml', waterGoal);
      }
      if (calorieGoal != null && calorieGoal > 0) {
        await _savePrefInt('calorie_goal', calorieGoal);
      }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).profileUpdated),
            backgroundColor: CoachDashboardTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.friendlyError(e)),
            backgroundColor: CoachDashboardTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to access your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CoachDashboardTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onLogout();
  }

  Future<void> _confirmChangePassword() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change password'),
        content: const Text('You will be asked for your current password and a new one.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await showChangePasswordDialog(context);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete account'),
        content: const Text(
          'Account deletion is handled by support to protect your data. '
          'Contact support@vitalfitness.app and we will process your request.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
              );
            },
            child: const Text('Contact support'),
          ),
        ],
      ),
    );
  }

  void _openHelp() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
    );
  }

  void _showInfoSheet(String title, String body) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF181B24) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.paddingOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: CoachDashboardTheme.sectionTitle(isDark)),
            const SizedBox(height: 12),
            Text(
              body,
              style: TextStyle(
                height: 1.45,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _statusLabel {
    if (_user.hasPendingCoachApplication) return 'Coach application pending';
    if (_user.isClient) return 'Active member';
    return _user.role.toUpperCase();
  }

  Color get _statusColor {
    if (_user.hasPendingCoachApplication) return CoachDashboardTheme.warning;
    return const Color(0xFF00D4AA);
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
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _refreshProfile,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: RefreshIndicator(
          onRefresh: _refreshProfile,
          child: ListView(
            controller: _scrollController,
            physics: dashboardScrollPhysics,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _profileHeader(isDark),
              if (_assignedCoachName != null && _assignedCoachName!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _coachBanner(isDark),
              ],
              const SizedBox(height: 18),
              _sectionLabel(isDark, 'Profile'),
              const SizedBox(height: 8),
              _settingsCard(
                isDark,
                children: [
                  _tile(
                    icon: Icons.edit_outlined,
                    color: CoachDashboardTheme.primary,
                    title: 'Edit profile',
                    subtitle: _profileExpanded ? 'Hide personal details' : 'Name, body metrics & goals',
                    trailing: Icon(
                      _profileExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    onTap: () => setState(() => _profileExpanded = !_profileExpanded),
                  ),
                  _divider(isDark),
                  _tile(
                    icon: Icons.photo_camera_outlined,
                    color: Colors.teal,
                    title: 'Change profile picture',
                    subtitle: 'Tap your photo above to update',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tap your profile photo to change it'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (_profileExpanded) ...[
                const SizedBox(height: 10),
                _personalInfoCard(isDark, l10n),
                const SizedBox(height: 10),
                _goalsCard(isDark, l10n),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: FilledButton.styleFrom(
                    backgroundColor: CoachDashboardTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l10n.saveProfileChanges),
                ),
              ],
              const SizedBox(height: 18),
              _sectionLabel(isDark, 'Account'),
              const SizedBox(height: 8),
              _settingsCard(
                isDark,
                children: [
                  _tile(
                    icon: Icons.lock_outline_rounded,
                    color: CoachDashboardTheme.primary,
                    title: 'Change password',
                    subtitle: 'Update your account password',
                    onTap: _confirmChangePassword,
                  ),
                  _divider(isDark),
                  SwitchListTile(
                    secondary: Icon(Icons.email_outlined, color: Colors.indigo.shade400),
                    title: const Text('Email preferences', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Weekly digest emails on this device'),
                    value: _emailDigest,
                    activeThumbColor: CoachDashboardTheme.primary,
                    onChanged: (v) {
                      setState(() => _emailDigest = v);
                      _savePrefBool('email_digest', v);
                    },
                  ),
                  _divider(isDark),
                  SwitchListTile(
                    secondary: const Icon(Icons.fitness_center_rounded, color: Color(0xFFFF6B6B)),
                    title: Text(l10n.workoutReminders, style: const TextStyle(fontWeight: FontWeight.w600)),
                    value: _notifWorkout,
                    activeThumbColor: const Color(0xFF00D4AA),
                    onChanged: (v) {
                      setState(() => _notifWorkout = v);
                      _savePrefBool('notif_workout', v);
                    },
                  ),
                  _divider(isDark),
                  SwitchListTile(
                    secondary: const Icon(Icons.event_rounded, color: Colors.blue),
                    title: Text(l10n.classUpdates, style: const TextStyle(fontWeight: FontWeight.w600)),
                    value: _notifClass,
                    activeThumbColor: const Color(0xFF00D4AA),
                    onChanged: (v) {
                      setState(() => _notifClass = v);
                      _savePrefBool('notif_class', v);
                    },
                  ),
                  _divider(isDark),
                  SwitchListTile(
                    secondary: const Icon(Icons.chat_bubble_rounded, color: Colors.purple),
                    title: Text(l10n.coachMessages, style: const TextStyle(fontWeight: FontWeight.w600)),
                    value: _notifCoach,
                    activeThumbColor: const Color(0xFF00D4AA),
                    onChanged: (v) {
                      setState(() => _notifCoach = v);
                      _savePrefBool('notif_coach', v);
                    },
                  ),
                  _divider(isDark),
                  _tile(
                    icon: Icons.privacy_tip_outlined,
                    color: Colors.blueGrey,
                    title: 'Privacy settings',
                    subtitle: 'How we use your profile data',
                    onTap: () => _showInfoSheet(
                      'Privacy settings',
                      'Your profile, progress, and messages are used to deliver coaching features. '
                          'You can update personal details anytime and sign out from this device. '
                          'For data deletion requests, use Delete account under Account actions.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _sectionLabel(isDark, 'Health & fitness'),
              const SizedBox(height: 8),
              _settingsCard(
                isDark,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _waterGoalController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Daily water goal (ml)',
                            prefixIcon: const Icon(Icons.water_drop_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (v) {
                            final n = int.tryParse(v.trim());
                            if (n != null && n > 0) _savePrefInt('water_goal_ml', n);
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _calorieGoalController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Daily calorie goal (kcal)',
                            prefixIcon: const Icon(Icons.local_fire_department_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (v) {
                            final n = int.tryParse(v.trim());
                            if (n != null && n > 0) _savePrefInt('calorie_goal', n);
                          },
                        ),
                      ],
                    ),
                  ),
                  _divider(isDark),
                  _tile(
                    icon: Icons.flag_outlined,
                    color: CoachDashboardTheme.success,
                    title: 'Weight goal',
                    subtitle: _goals.isEmpty
                        ? 'Select fitness goals in Edit profile'
                        : _goals.join(', '),
                    onTap: () => setState(() => _profileExpanded = true),
                  ),
                  _divider(isDark),
                  ListTile(
                    leading: Icon(Icons.directions_run_outlined, color: Colors.orange.shade700),
                    title: const Text('Activity level', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_activityLevelLabel(_activityLevel)),
                    trailing: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: ['sedentary', 'moderate', 'active'].contains(_activityLevel)
                            ? _activityLevel
                            : 'moderate',
                        items: const [
                          DropdownMenuItem(value: 'sedentary', child: Text('Sedentary')),
                          DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          _updateActivityLevel(v);
                        },
                      ),
                    ),
                  ),
                  _divider(isDark),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.straighten_rounded, color: CoachDashboardTheme.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Measurement units', style: TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    _unitSystem == 'metric' ? 'kg · cm' : 'lbs · ft',
                                    style: CoachDashboardTheme.bodyMuted(isDark).copyWith(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'metric', label: Text('Metric')),
                              ButtonSegment(value: 'imperial', label: Text('US')),
                            ],
                            selected: {_unitSystem},
                            onSelectionChanged: (s) {
                              final v = s.first;
                              setState(() => _unitSystem = v);
                              _savePrefString('unit_system', v);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _sectionLabel(isDark, 'App settings'),
              const SizedBox(height: 8),
              _settingsCard(
                isDark,
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.dark_mode_rounded, color: CoachDashboardTheme.primary),
                    title: Text(l10n.darkMode, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Theme preference'),
                    value: widget.isDark,
                    activeThumbColor: CoachDashboardTheme.primary,
                    onChanged: widget.onThemeToggle,
                  ),
                  _divider(isDark),
                  _tile(
                    icon: Icons.language_rounded,
                    color: Colors.orange,
                    title: l10n.language,
                    subtitle: l10n.languageLabel(localeCode),
                    onTap: () => showLanguagePicker(context),
                  ),
                  _divider(isDark),
                  SwitchListTile(
                    secondary: const Icon(Icons.volume_up_outlined, color: Colors.teal),
                    title: const Text('Sounds', style: TextStyle(fontWeight: FontWeight.w600)),
                    value: _soundEnabled,
                    activeThumbColor: const Color(0xFF00D4AA),
                    onChanged: (v) {
                      setState(() => _soundEnabled = v);
                      _savePrefBool('sound_enabled', v);
                      if (v) SystemSound.play(SystemSoundType.click);
                    },
                  ),
                  _divider(isDark),
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration_rounded, color: Colors.deepPurple),
                    title: const Text('Vibration', style: TextStyle(fontWeight: FontWeight.w600)),
                    value: _vibrationEnabled,
                    activeThumbColor: const Color(0xFF00D4AA),
                    onChanged: (v) {
                      setState(() => _vibrationEnabled = v);
                      _savePrefBool('vibration_enabled', v);
                      if (v) HapticFeedback.selectionClick();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _sectionLabel(isDark, 'Support'),
              const SizedBox(height: 8),
              _settingsCard(
                isDark,
                children: [
                  _tile(
                    icon: Icons.help_outline_rounded,
                    color: CoachDashboardTheme.primary,
                    title: 'Help center',
                    subtitle: 'Guides and FAQs',
                    onTap: _openHelp,
                  ),
                  _divider(isDark),
                  _tile(
                    icon: Icons.quiz_outlined,
                    color: Colors.indigo,
                    title: 'FAQ',
                    subtitle: 'Common questions',
                    onTap: _openHelp,
                  ),
                  _divider(isDark),
                  _tile(
                    icon: Icons.support_agent_rounded,
                    color: Colors.teal,
                    title: 'Contact support',
                    subtitle: 'support@vitalfitness.app',
                    onTap: _openHelp,
                  ),
                  _divider(isDark),
                  _tile(
                    icon: Icons.report_outlined,
                    color: CoachDashboardTheme.warning,
                    title: 'Report a problem',
                    subtitle: 'Tell us what went wrong',
                    onTap: _openHelp,
                  ),
                  _divider(isDark),
                  _tile(
                    icon: Icons.feedback_outlined,
                    color: Colors.purple,
                    title: 'Send feedback',
                    subtitle: 'Ideas to improve Vital Fitness',
                    onTap: _openHelp,
                  ),
                  _divider(isDark),
                  _tile(
                    icon: Icons.person_add_alt_1_rounded,
                    color: CoachDashboardTheme.primary,
                    title: 'Invite friends',
                    subtitle: 'Share your invite link',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const InviteFriendsScreen()),
                      );
                    },
                  ),
                  _divider(isDark),
                  _tile(
                    icon: Icons.ios_share_rounded,
                    color: Colors.teal,
                    title: 'Share weekly win',
                    subtitle: 'Create a public progress card',
                    onTap: () => shareVitalCard(context, type: 'weekly'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _sectionLabel(isDark, 'About'),
              const SizedBox(height: 8),
              _settingsCard(
                isDark,
                children: [
                  _tile(
                    icon: Icons.info_outline_rounded,
                    color: CoachDashboardTheme.primary,
                    title: 'App version',
                    subtitle: kAppVersionLabel,
                    showChevron: false,
                  ),
                  _divider(isDark),
                  _tile(
                    icon: Icons.privacy_tip_outlined,
                    color: Colors.blueGrey,
                    title: 'Privacy policy',
                    onTap: () => _showInfoSheet(
                      'Privacy policy',
                      'Vital Fitness stores account, coaching, diet, and progress data to provide the service. '
                          'We do not sell your personal information. Contact support for privacy questions or deletion requests.',
                    ),
                  ),
                  _divider(isDark),
                  _tile(
                    icon: Icons.description_outlined,
                    color: Colors.brown,
                    title: 'Terms & conditions',
                    onTap: () => _showInfoSheet(
                      'Terms & conditions',
                      'By using Vital Fitness you agree to use the app responsibly, follow coach guidance, '
                          'and keep your login credentials secure. Coaching advice is not a substitute for medical care.',
                    ),
                  ),
                  _divider(isDark),
                  _tile(
                    icon: Icons.favorite_outline_rounded,
                    color: const Color(0xFFDB2777),
                    title: 'About the app',
                    onTap: () => _showInfoSheet(
                      'About Vital Fitness',
                      'Vital Fitness connects members with coaches for workouts, diet plans, progress tracking, and messaging — all in one place.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _sectionLabel(isDark, 'Account actions'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _confirmLogout,
                icon: const Icon(Icons.logout_rounded),
                label: Text(l10n.signOut, style: const TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF6B6B),
                  side: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _confirmDeleteAccount,
                icon: const Icon(Icons.delete_forever_outlined, size: 18),
                label: const Text('Delete account'),
                style: TextButton.styleFrom(foregroundColor: CoachDashboardTheme.danger),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateActivityLevel(String value) async {
    setState(() => _activityLevel = value);
    try {
      final updatedProfile = await _apiService.updateProfile(activityLevel: value);
      if (!mounted) return;
      final updatedUser = _user.copyWith(
        profile: updatedProfile.copyWith(
          assignedCoachName: _assignedCoachName,
          photoUrl: _photoUrl ?? updatedProfile.photoUrl,
        ),
      );
      _user = updatedUser;
      widget.onUserUpdated(updatedUser);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiService.friendlyError(e)),
          backgroundColor: CoachDashboardTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _activityLevelLabel(String value) {
    switch (value) {
      case 'sedentary':
        return 'Sedentary';
      case 'active':
        return 'Active';
      default:
        return 'Moderate';
    }
  }

  Widget _sectionLabel(bool isDark, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
        color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
      ),
    );
  }

  Widget _settingsCard(bool isDark, {required List<Widget> children}) {
    return Container(
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _divider(bool isDark) =>
      Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12);

  Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool showChevron = true,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing ??
          (showChevron && onTap != null
              ? const Icon(Icons.chevron_right_rounded, color: Colors.grey)
              : null),
      onTap: onTap,
    );
  }

  Widget _profileHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Row(
        children: [
          ProfileAvatar(
            name: _user.name,
            photoUrl: _photoUrl,
            radius: 36,
            editable: true,
            backgroundColor: CoachDashboardTheme.primary,
            onPhotoChanged: _onPhotoChanged,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(_user.email, style: CoachDashboardTheme.bodyMuted(isDark)),
                if (_phoneController.text.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_phoneController.text, style: CoachDashboardTheme.bodyMuted(isDark).copyWith(fontSize: 12)),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coachBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: CoachDashboardTheme.cardDecoration(isDark).copyWith(
        border: Border.all(color: CoachDashboardTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_outlined, color: CoachDashboardTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assigned coach', style: CoachDashboardTheme.bodyMuted(isDark).copyWith(fontSize: 12)),
                Text(_assignedCoachName!, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _personalInfoCard(bool isDark, AppLocalizations l10n) {
    final bmi = _computedBmi;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal information', style: CoachDashboardTheme.sectionTitle(isDark).copyWith(fontSize: 15)),
          const SizedBox(height: 12),
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
                label: _unitSystem == 'metric' ? l10n.heightCm : 'Height',
                unit: _unitSystem == 'metric' ? 'cm' : 'cm',
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
                label: _unitSystem == 'metric' ? l10n.weightKg : 'Weight',
                unit: _unitSystem == 'metric' ? 'kg' : 'kg',
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
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1117) : const Color(0xFFF3F4F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.insights_rounded, size: 18, color: _bmiColor(bmi)),
                  const SizedBox(width: 8),
                  Text(l10n.bmi, style: CoachDashboardTheme.bodyMuted(isDark)),
                  const Spacer(),
                  Text(bmi.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.w800, color: _bmiColor(bmi))),
                  const SizedBox(width: 8),
                  Text(_bmiLabel(bmi), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _bmiColor(bmi))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
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
    );
  }

  Widget _goalsCard(bool isDark, AppLocalizations l10n) {
    return Container(
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Text(l10n.fitnessGoals, style: CoachDashboardTheme.sectionTitle(isDark).copyWith(fontSize: 15)),
          ),
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
                  title: Text(g, style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                if (i < _availableGoals.length - 1) _divider(isDark),
              ],
            );
          }),
        ],
      ),
    );
  }

  double? get _computedBmi {
    final heightCm = double.tryParse(_heightController.text);
    final weightKg = double.tryParse(_weightController.text);
    if (heightCm == null || weightKg == null || heightCm <= 0) return null;
    final heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
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
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1117) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? const Color(0xFF2A2F3D) : const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54)),
            TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: '—',
                suffixText: unit,
                border: InputBorder.none,
                isDense: true,
                errorStyle: const TextStyle(fontSize: 9),
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
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Over';
    return 'Obese';
  }
}
