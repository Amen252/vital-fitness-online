import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/coach_application_prefs.dart';
import 'login_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/coach_dashboard_screen.dart';
import '../admin/dashboard/admin_dashboard_screen.dart';
import 'coach_pending_screen.dart';
import 'coach_rejected_screen.dart';

class AuthRouting {
  static Future<Widget> resolveHome(User? user) async {
    if (user == null) return const LoginScreen();
    if (user.role == 'admin') return AdminDashboardScreen(adminUser: user);
    // A coach with a pending/rejected application is gated until an admin
    // reviews it; only approved coaches reach the coach dashboard.
    if (user.role == 'coach') {
      if (user.coachApplicationStatus == 'pending') {
        return CoachPendingScreen(user: user);
      }
      if (user.coachApplicationStatus == 'rejected') {
        return CoachRejectedScreen(user: user);
      }
      return CoachDashboardScreen(coachUser: user);
    }
    if (user.coachApplicationStatus == 'pending') {
      return CoachPendingScreen(user: user);
    }
    if (user.coachApplicationStatus == 'rejected') {
      final showRejected = await CoachApplicationPrefs.shouldShowRejectionScreen(
        userId: user.id,
        reviewedAt: user.coachApplicationReviewedAt,
      );
      if (showRejected) return CoachRejectedScreen(user: user);
    }
    return DashboardScreen(initialUser: user);
  }

  static Widget homeForUser(User? user) {
    if (user == null) return const LoginScreen();
    if (user.role == 'admin') return AdminDashboardScreen(adminUser: user);
    if (user.role == 'coach') {
      if (user.coachApplicationStatus == 'pending') {
        return CoachPendingScreen(user: user);
      }
      if (user.coachApplicationStatus == 'rejected') {
        return CoachRejectedScreen(user: user);
      }
      return CoachDashboardScreen(coachUser: user);
    }
    if (user.coachApplicationStatus == 'pending') {
      return CoachPendingScreen(user: user);
    }
    // Rejection UX is handled asynchronously in resolveHome.
    return DashboardScreen(initialUser: user);
  }
}
