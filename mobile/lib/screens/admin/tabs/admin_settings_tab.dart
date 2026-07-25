import 'package:flutter/material.dart';
import '../../dashboard/widgets/coach_home/coach_dashboard_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/api_service.dart';
import '../../../controllers/admin_tab_controller.dart';
import '../../../widgets/scrollable_body.dart';
import '../../../widgets/account/change_password_dialog.dart';
import '../../support/help_support_screen.dart';
import '../../../main.dart';
import '../../auth/login_screen.dart';

class AdminSettingsTab extends StatelessWidget {
  final User adminUser;
  final ApiService _apiService = ApiService();

  AdminSettingsTab({super.key, required this.adminUser});

  void _handleLogout(BuildContext context) async {
    await _apiService.clearAuth();
    AdminTabController.instance.reset();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final myApp = MyApp.of(context);

    return SingleChildScrollView(
      physics: dashboardScrollPhysics,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: CoachDashboardTheme.cardDecoration(isDark),
            child: Row(
              children: [
                CoachDashboardTheme.avatarBox(
                  initial: adminUser.name.isNotEmpty ? adminUser.name[0].toUpperCase() : 'A',
                  size: 56,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(adminUser.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(adminUser.email, style: TextStyle(color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: CoachDashboardTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Administrator', style: TextStyle(color: CoachDashboardTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Preferences', style: CoachDashboardTheme.sectionTitle(isDark)),
          const SizedBox(height: 8),
          Container(
            decoration: CoachDashboardTheme.cardDecoration(isDark),
            child: SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: Text(isDark ? 'Enabled' : 'Disabled'),
              value: isDark,
              activeThumbColor: CoachDashboardTheme.primary,
              onChanged: (val) => myApp?.toggleTheme(val),
            ),
          ),
          const SizedBox(height: 24),
          Text('Account', style: CoachDashboardTheme.sectionTitle(isDark)),
          const SizedBox(height: 8),
          Container(
            decoration: CoachDashboardTheme.cardDecoration(isDark),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showChangePasswordDialog(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'VitalFitness Admin',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(Icons.fitness_center, size: 48, color: CoachDashboardTheme.primary),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: CoachDashboardTheme.danger),
                  title: const Text('Sign Out', style: TextStyle(color: CoachDashboardTheme.danger, fontWeight: FontWeight.w600)),
                  onTap: () => _handleLogout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
