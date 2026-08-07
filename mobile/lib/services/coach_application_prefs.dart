import 'package:shared_preferences/shared_preferences.dart';

class CoachApplicationPrefs {
  static String _dismissedKey(String userId) => 'coach_rejection_dismissed_$userId';
  static const _anySentinel = 'any';

  static String _tokenFor(DateTime? reviewedAt) =>
      reviewedAt?.toUtc().toIso8601String() ?? _anySentinel;

  static Future<bool> shouldShowRejectionScreen({
    required String userId,
    required DateTime? reviewedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getString(_dismissedKey(userId));
    if (dismissed == null) return true;
    final current = _tokenFor(reviewedAt);
    // Match exact review timestamp, or a prior "any" dismiss for null reviewedAt.
    return dismissed != current && !(dismissed == _anySentinel && reviewedAt == null);
  }

  static Future<void> dismissRejection({
    required String userId,
    required DateTime? reviewedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedKey(userId), _tokenFor(reviewedAt));
  }

  static Future<void> clearRejectionDismissed(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedKey(userId));
  }
}
