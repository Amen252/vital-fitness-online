import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../dashboard/widgets/coach_home/coach_dashboard_theme.dart';
import 'auth_routing.dart';

/// Resolves the correct home for a signed-in user (client / coach / admin).
class AuthHome extends StatefulWidget {
  final User? user;

  /// When opening the member (client) shell, optionally land on a tab
  /// (e.g. coaches after register — matches web `/member/coaches`).
  final int? memberInitialTabIndex;

  const AuthHome({
    super.key,
    required this.user,
    this.memberInitialTabIndex,
  });

  @override
  State<AuthHome> createState() => _AuthHomeState();
}

class _AuthHomeState extends State<AuthHome> {
  Widget? _home;

  @override
  void initState() {
    super.initState();
    _resolveHome();
  }

  @override
  void didUpdateWidget(covariant AuthHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.id != widget.user?.id ||
        oldWidget.user?.role != widget.user?.role ||
        oldWidget.user?.mustChangePassword != widget.user?.mustChangePassword ||
        oldWidget.user?.coachApplicationStatus !=
            widget.user?.coachApplicationStatus ||
        oldWidget.memberInitialTabIndex != widget.memberInitialTabIndex) {
      _home = null;
      _resolveHome();
    }
  }

  Future<void> _resolveHome() async {
    final home = await AuthRouting.resolveHome(
      widget.user,
      memberInitialTabIndex: widget.memberInitialTabIndex,
    );
    if (mounted) setState(() => _home = home);
  }

  @override
  Widget build(BuildContext context) {
    if (_home == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: CoachDashboardTheme.primary),
        ),
      );
    }
    return _home!;
  }
}
