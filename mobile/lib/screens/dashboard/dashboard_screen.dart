import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../utils/coach_thread_utils.dart';
import '../../widgets/animations/animations.dart';
import '../auth/login_screen.dart';
import '../../main.dart';
import 'tabs/home_tab.dart';
import 'assignments_screen.dart';
import 'notifications_screen.dart';
import 'user_appointments_screen.dart';
import 'tabs/user_schedule_tab.dart';
import 'user_diet_plan_screen.dart';
import 'tabs/user_progress_tab.dart';
import 'tabs/user_coaches_tab.dart';
import 'tabs/user_settings_tab.dart';
import 'widgets/user_sidebar.dart';
import 'widgets/coach_home/coach_dashboard_theme.dart';
import '../auth/auth_landing_theme.dart';

class DashboardScreen extends StatefulWidget {
  final User initialUser;
  final int initialTabIndex;

  const DashboardScreen({
    super.key,
    required this.initialUser,
    this.initialTabIndex = 0,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late User _currentUser;
  late int _currentIndex;
  int _unreadCoachMessages = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ApiService _apiService = ApiService();
  final GlobalKey<HomeTabState> _homeTabKey = GlobalKey<HomeTabState>();
  final GlobalKey<UserDietPlanScreenState> _dietTabKey = GlobalKey<UserDietPlanScreenState>();

  static const _navIcons = [
    (Icons.home_outlined, Icons.home_rounded),
    (Icons.restaurant_menu_outlined, Icons.restaurant_menu_rounded),
    (Icons.bar_chart_outlined, Icons.bar_chart_rounded),
    (Icons.person_pin_circle_outlined, Icons.person_pin_circle_rounded),
    (Icons.settings_outlined, Icons.settings_rounded),
  ];

  List<String> _navLabels(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [l10n.home, l10n.dietPlan, l10n.progress, l10n.coaches, l10n.settings];
  }

  @override
  void initState() {
    super.initState();
    _currentUser = widget.initialUser;
    _currentIndex = widget.initialTabIndex.clamp(0, _navIcons.length - 1);
    _loadUnreadCoachMessages();
  }

  Future<void> _loadUnreadCoachMessages() async {
    try {
      final threads = await _apiService.getChatThreads();
      var total = 0;
      for (final t in threads) {
        total += CoachThreadUtils.unreadCount(Map<String, dynamic>.from(t as Map));
      }
      if (mounted) setState(() => _unreadCoachMessages = total);
    } catch (_) {}
  }

  void _onScheduleDataChanged() {
    _homeTabKey.currentState?.refresh();
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) {
      _homeTabKey.currentState?.refresh();
    } else if (index == 1) {
      _dietTabKey.currentState?.refresh();
    } else if (index == 3) {
      _loadUnreadCoachMessages();
    }
  }

  void _openCoachSchedule({DateTime? weekStart}) {
    _openSection(_scheduleScreen(initialWeekStart: weekStart));
  }

  void _onUserUpdated(User updatedUser) {
    setState(() {
      _currentUser = updatedUser;
    });
  }

  Future<void> _handleLogout() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await _apiService.clearAuth();
      AppNavigator.pushAndRemoveUntil(
        context,
        const LoginScreen(),
        (route) => false,
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text("Failed to log out: $e"),
          backgroundColor: CoachDashboardTheme.danger,
        ),
      );
    }
  }

  List<Widget> _buildTabs() {
    final myAppState = MyApp.of(context);
    final isDark = myAppState?.isDark ?? false;
    final toggleTheme = myAppState?.toggleTheme ?? (bool _) {};

    return [
      HomeTab(
        key: _homeTabKey,
        user: _currentUser,
        onOpenDietPlan: () => _onTabSelected(1),
        onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      UserDietPlanScreen(key: _dietTabKey),
      UserProgressTab(user: _currentUser),
      UserCoachesTab(user: _currentUser, onUnreadChanged: _loadUnreadCoachMessages),
      UserSettingsTab(
        user: _currentUser,
        onUserUpdated: _onUserUpdated,
        onLogout: _handleLogout,
        onThemeToggle: toggleTheme,
        isDark: isDark,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      drawer: UserSidebar(
        user: _currentUser,
        onOpenSchedule: () => _openSection(_scheduleScreen()),
        onOpenAppointments: () => _openSection(const UserAppointmentsScreen()),
        onOpenWorkouts: _openWorkouts,
        onOpenNotifications: () => _openSection(NotificationsScreen(onOpenCoachSchedule: _openCoachSchedule)),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _buildTabs(),
        ),
      ),
      bottomNavigationBar: AnimatedBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        isDark: isDark,
        activeColor: CoachDashboardTheme.primary,
        inactiveColor: isDark ? AuthLandingTheme.footer : AuthLandingTheme.footer,
        items: List.generate(_navIcons.length, (i) {
          final (inactive, active) = _navIcons[i];
          return AnimatedNavItem(
            inactiveIcon: inactive,
            activeIcon: active,
            label: _navLabels(context)[i],
            badge: i == 3 ? _unreadCoachMessages : null,
          );
        }),
      ),
    );
  }

  void _openSection(Widget screen) {
    AppNavigator.push(context, screen);
  }

  Future<void> _openWorkouts() async {
    try {
      final coachingData = await _apiService.getUserCoaching();
      if (!mounted) return;
      if (coachingData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No coach assigned yet!')),
        );
        return;
      }
      _openSection(AssignmentsScreen(coachingData: coachingData));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiService.friendlyError(e)),
          backgroundColor: CoachDashboardTheme.danger,
        ),
      );
    }
  }

  Widget _scheduleScreen({DateTime? initialWeekStart}) {
    return UserScheduleTab(
      user: _currentUser,
      onScheduleDataChanged: _onScheduleDataChanged,
      initialWeekStart: initialWeekStart,
    );
  }
}
