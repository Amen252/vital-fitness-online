import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/coach_application_prefs.dart';
import 'login_screen.dart';
import 'force_change_password_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/coach_dashboard_screen.dart';
import '../admin/dashboard/admin_dashboard_screen.dart';
import 'coach_pending_screen.dart';
import 'coach_rejected_screen.dart';

/// Role-based home resolution — mirrors web `dashboardPath()` + `SessionGuard`.
///
/// | Role / state                         | Destination              |
/// |--------------------------------------|--------------------------|
/// | signed out                           | Login                    |
/// | must_change_password                 | Force change password    |
/// | admin                                | Admin dashboard          |
/// | coach (approved)                     | Coach dashboard          |
/// | coach/user with pending application  | Coach pending gate       |
/// | user with rejected application       | Coach rejected (optional)|
/// | user (client/member)                 | Member dashboard         |
class AuthRouting {
  /// Coaches tab on the member shell (same intent as web `/member/coaches`).
  static const int memberCoachesTabIndex = 3;

  static Future<Widget> resolveHome(
    User? user, {
    int? memberInitialTabIndex,
  }) async {
    if (user == null) return const LoginScreen();

    // Web SessionGuard: block everything until password is changed.
    if (user.mustChangePassword) {
      return ForceChangePasswordScreen(
        user: user,
        memberInitialTabIndex: memberInitialTabIndex,
      );
    }

    if (user.isAdmin) {
      return AdminDashboardScreen(adminUser: user);
    }

    // Approved coaches land on the coach shell (web `/coach/*`).
    // Pending/rejected coach applications stay gated.
    if (user.isCoach) {
      if (user.hasPendingCoachApplication) {
        return CoachPendingScreen(user: user);
      }
      if (user.hasRejectedCoachApplication) {
        return CoachRejectedScreen(user: user);
      }
      return CoachDashboardScreen(coachUser: user);
    }

    // Clients (role `user`) may have applied to become a coach.
    if (user.hasPendingCoachApplication) {
      return CoachPendingScreen(user: user);
    }
    if (user.hasRejectedCoachApplication) {
      final showRejected = await CoachApplicationPrefs.shouldShowRejectionScreen(
        userId: user.id,
        reviewedAt: user.coachApplicationReviewedAt,
      );
      if (showRejected) return CoachRejectedScreen(user: user);
    }

    // Client / member shell (web `/member/*`).
    return DashboardScreen(
      initialUser: user,
      initialTabIndex: memberInitialTabIndex ?? 0,
    );
  }

  /// Sync helper for callers that cannot await. Rejection-dismiss prefs are
  /// skipped — prefer [resolveHome] for full parity with the web.
  static Widget homeForUser(User? user, {int? memberInitialTabIndex}) {
    if (user == null) return const LoginScreen();
    if (user.mustChangePassword) {
      return ForceChangePasswordScreen(
        user: user,
        memberInitialTabIndex: memberInitialTabIndex,
      );
    }
    if (user.isAdmin) return AdminDashboardScreen(adminUser: user);
    if (user.isCoach) {
      if (user.hasPendingCoachApplication) {
        return CoachPendingScreen(user: user);
      }
      if (user.hasRejectedCoachApplication) {
        return CoachRejectedScreen(user: user);
      }
      return CoachDashboardScreen(coachUser: user);
    }
    if (user.hasPendingCoachApplication) {
      return CoachPendingScreen(user: user);
    }
    return DashboardScreen(
      initialUser: user,
      initialTabIndex: memberInitialTabIndex ?? 0,
    );
  }
}
