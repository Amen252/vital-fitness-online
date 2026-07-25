import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../widgets/admin_sidebar.dart';
import '../tabs/admin_users_tab.dart';
import '../tabs/admin_home_tab.dart';
import '../tabs/admin_coaches_tab.dart';
import '../tabs/admin_settings_tab.dart';
import '../../../controllers/admin_tab_controller.dart';
import '../../dashboard/widgets/coach_home/coach_dashboard_theme.dart';
import '../../auth/auth_landing_theme.dart';
import '../../../widgets/animations/animated_bottom_nav.dart';
import '../screens/admin_reports_screen.dart';
import '../screens/admin_activity_screen.dart';
import '../screens/admin_notifications_screen.dart';
import '../tabs/admin_classes_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  final User adminUser;

  const AdminDashboardScreen({
    super.key,
    required this.adminUser,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminTabController _controller = AdminTabController.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<AdminHomeTabState> _homeKey = GlobalKey<AdminHomeTabState>();
  final GlobalKey<AdminCoachesTabState> _coachesKey = GlobalKey<AdminCoachesTabState>();
  final GlobalKey<AdminUsersTabState> _usersKey = GlobalKey<AdminUsersTabState>();

  late final List<Widget> _tabs;

  static const _navItems = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.school_outlined, Icons.school_rounded, 'Coaches'),
    (Icons.people_alt_outlined, Icons.people_alt_rounded, 'Users'),
    (Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = [
      AdminHomeTab(key: _homeKey, adminUser: widget.adminUser),
      AdminCoachesTab(key: _coachesKey, adminUser: widget.adminUser),
      AdminUsersTab(key: _usersKey, adminUser: widget.adminUser),
      AdminSettingsTab(adminUser: widget.adminUser),
    ];
  }

  void _refreshCurrentTab() {
    switch (_controller.currentIndex.value) {
      case 0:
        _homeKey.currentState?.refresh();
        break;
      case 1:
        _coachesKey.currentState?.refresh();
        break;
      case 2:
        _usersKey.currentState?.refresh();
        break;
    }
  }

  List<Widget> _appBarActions(int index) {
    if (index >= 3) return [];
    return [
      IconButton(
        icon: const Icon(Icons.refresh_rounded),
        onPressed: _refreshCurrentTab,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = widget.adminUser.name.isNotEmpty
        ? widget.adminUser.name[0].toUpperCase()
        : 'A';

    return ValueListenableBuilder<int>(
      valueListenable: _controller.currentIndex,
      builder: (context, currentIndex, _) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: CoachDashboardTheme.homeBackground(isDark),
          drawer: AdminSidebar(
            adminUser: widget.adminUser,
            initial: initial,
            onOpenReports: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminReportsScreen()),
            ),
            onOpenClasses: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => Scaffold(
                  backgroundColor: CoachDashboardTheme.homeBackground(isDark),
                  appBar: CoachDashboardTheme.coachAppBar(
                    context: ctx,
                    title: 'Classes',
                    centerTitle: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () {
                          AdminClassesTab.globalRefreshKey.currentState?.refresh();
                        },
                      ),
                    ],
                  ),
                  body: AdminClassesTab(
                    key: AdminClassesTab.globalRefreshKey,
                    adminUser: widget.adminUser,
                  ),
                ),
              ),
            ),
            onOpenActivity: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminActivityScreen()),
            ),
            onOpenAnnouncements: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminNotificationsScreen()),
            ),
          ),
          appBar: CoachDashboardTheme.coachAppBar(
            context: context,
            title: AdminTabController.tabTitles[currentIndex],
            centerTitle: false,
            actions: _appBarActions(currentIndex),
          ),
          body: SafeArea(
            top: false,
            child: IndexedStack(
              index: currentIndex,
              children: _tabs,
            ),
          ),
          bottomNavigationBar: AnimatedBottomNav(
            currentIndex: currentIndex,
            onTap: _controller.setIndex,
            isDark: isDark,
            activeColor: CoachDashboardTheme.primary,
            inactiveColor: AuthLandingTheme.footer,
            items: _navItems
                .map(
                  (item) => AnimatedNavItem(
                    inactiveIcon: item.$1,
                    activeIcon: item.$2,
                    label: item.$3,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}
