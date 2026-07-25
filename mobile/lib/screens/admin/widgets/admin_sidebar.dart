import 'package:flutter/material.dart';
import '../../../controllers/admin_tab_controller.dart';
import '../../../models/user_model.dart';
import '../../dashboard/widgets/coach_home/coach_dashboard_theme.dart';

class AdminSidebar extends StatelessWidget {
  final User adminUser;
  final String initial;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenClasses;
  final VoidCallback onOpenActivity;
  final VoidCallback onOpenAnnouncements;

  const AdminSidebar({
    super.key,
    required this.adminUser,
    required this.initial,
    required this.onOpenReports,
    required this.onOpenClasses,
    required this.onOpenActivity,
    required this.onOpenAnnouncements,
  });

  void _navigate(BuildContext context, int index) {
    AdminTabController.instance.setIndex(index);
    Navigator.pop(context);
  }

  void _push(BuildContext context, VoidCallback action) {
    Navigator.pop(context);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: CoachDashboardTheme.drawerBackground(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            decoration: const BoxDecoration(gradient: CoachDashboardTheme.headerGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: CoachDashboardTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  adminUser.name,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  adminUser.email,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Administrator',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: AdminTabController.instance.currentIndex,
              builder: (context, currentIndex, _) {
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _drawerLabel('MAIN', isDark),
                    _buildDrawerItem(context, Icons.home_rounded, 'Home', 0, isDark, currentIndex),
                    _buildDrawerItem(context, Icons.school_rounded, 'Coaches', 1, isDark, currentIndex),
                    _buildDrawerItem(context, Icons.people_alt_rounded, 'Users', 2, isDark, currentIndex),
                    _buildDrawerItem(context, Icons.settings_rounded, 'Settings', 3, isDark, currentIndex),
                    const SizedBox(height: 8),
                    _drawerLabel('MANAGEMENT', isDark),
                    _buildDrawerPush(context, Icons.fitness_center_rounded, 'Classes', isDark, () {
                      _push(context, onOpenClasses);
                    }),
                    _buildDrawerPush(context, Icons.rule_rounded, 'Activity Review', isDark, () {
                      _push(context, onOpenActivity);
                    }),
                    _buildDrawerPush(context, Icons.campaign_rounded, 'Announcements', isDark, () {
                      _push(context, onOpenAnnouncements);
                    }),
                    const SizedBox(height: 8),
                    _drawerLabel('REPORTS', isDark),
                    _buildDrawerPush(context, Icons.analytics_rounded, 'Analytics', isDark, () {
                      _push(context, onOpenReports);
                    }),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(text, style: CoachDashboardTheme.sectionLabel(isDark)),
    );
  }

  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, int index, bool isDark, int currentIndex) {
    final selected = currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: selected ? CoachDashboardTheme.primary.withValues(alpha: isDark ? 0.2 : 0.08) : null,
        leading: Icon(icon, size: 20, color: selected ? CoachDashboardTheme.primary : (isDark ? Colors.white54 : CoachDashboardTheme.textSecondary)),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? CoachDashboardTheme.primary : (isDark ? Colors.white70 : CoachDashboardTheme.textPrimary),
          ),
        ),
        onTap: () => _navigate(context, index),
      ),
    );
  }

  Widget _buildDrawerPush(BuildContext context, IconData icon, String title, bool isDark, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(icon, size: 20, color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
        title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : CoachDashboardTheme.textPrimary)),
        trailing: Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white24 : Colors.black26),
        onTap: onTap,
      ),
    );
  }
}
