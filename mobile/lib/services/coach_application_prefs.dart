import 'package:shared_preferences/shared_preferences.dart';

class CoachApplicationPrefs {
  static String _dismissedKey(String userId) => 'coach_rejection_dismissed_$userId';

  static Future<bool> shouldShowRejectionScreen({
    required String userId,
    required DateTime? reviewedAt,
  }) async {
    if (reviewedAt == null) return true;
    final prefs = await SharedPreferences.getInstance();
    final dismissedReviewedAt = prefs.getString(_dismissedKey(userId));
    return dismissedReviewedAt != reviewedAt.toIso8601String();
  }

  static Future<void> dismissRejection({
    required String userId,
    required DateTime? reviewedAt,
  }) async {
    if (reviewedAt == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedKey(userId), reviewedAt.toIso8601String());
  }

  static Future<void> clearRejectionDismissed(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedKey(userId));
  }
}
