import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../dashboard/widgets/coach_home/coach_dashboard_theme.dart';
import 'auth_routing.dart';

class AuthHome extends StatefulWidget {
  final User? user;

  const AuthHome({super.key, required this.user});

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

  Future<void> _resolveHome() async {
    final home = await AuthRouting.resolveHome(widget.user);
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
