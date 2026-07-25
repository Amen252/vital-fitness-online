import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/dashboard/widgets/coach_home/coach_dashboard_theme.dart';

/// Helpers for coach-uploaded workout demo video / image URLs.
class WorkoutMediaUrls {
  WorkoutMediaUrls._();

  /// Normalize a coach-entered URL so it always has a usable scheme.
  static String? normalize(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;

    var candidate = value;
    final lower = candidate.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      if (lower.startsWith('www.') ||
          lower.contains('youtube.com') ||
          lower.contains('youtu.be') ||
          lower.contains('vimeo.com')) {
        candidate = 'https://$candidate';
      } else if (!candidate.contains('.') || candidate.contains(' ')) {
        return null;
      } else {
        candidate = 'https://$candidate';
      }
    }

    return _canonicalizeVideoUrl(candidate);
  }

  /// Prefer a stable https YouTube watch URL over short/share links.
  static String _canonicalizeVideoUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;

    final host = uri.host.toLowerCase();
    if (host == 'youtu.be' || host == 'www.youtu.be') {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (id.isNotEmpty) {
        return Uri.https('www.youtube.com', '/watch', {'v': id}).toString();
      }
    }

    if (host.endsWith('youtube.com')) {
      final v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) {
        return Uri.https('www.youtube.com', '/watch', {'v': v}).toString();
      }
      // /shorts/<id> or /embed/<id>
      if (uri.pathSegments.length >= 2 &&
          (uri.pathSegments.first == 'shorts' || uri.pathSegments.first == 'embed')) {
        final id = uri.pathSegments[1];
        if (id.isNotEmpty) {
          return Uri.https('www.youtube.com', '/watch', {'v': id}).toString();
        }
      }
    }

    return uri.toString();
  }

  static Uri? parse(String? raw) {
    final normalized = normalize(raw);
    if (normalized == null) return null;
    return Uri.tryParse(normalized);
  }

  /// Opens the video in the device browser / YouTube app.
  static Future<bool> open(
    BuildContext context,
    String? raw, {
    String failureMessage = 'Could not open this video link.',
  }) async {
    final uri = parse(raw);
    if (uri == null) {
      _toast(context, failureMessage);
      return false;
    }

    const modes = <LaunchMode>[
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
      LaunchMode.inAppBrowserView,
    ];

    for (final mode in modes) {
      try {
        final canLaunch = await canLaunchUrl(uri);
        if (!canLaunch && mode == LaunchMode.externalApplication) {
          continue;
        }
        final launched = await launchUrl(uri, mode: mode);
        if (launched) return true;
      } catch (_) {
        // Try the next launch mode.
      }
    }

    if (context.mounted) _toast(context, failureMessage);
    return false;
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: CoachDashboardTheme.danger,
      ),
    );
  }
}

/// Compact exercise row used on member workout screens.
class WorkoutExerciseRow extends StatelessWidget {
  final Map<dynamic, dynamic> exercise;
  final bool isDark;
  final bool showSetsReps;

  const WorkoutExerciseRow({
    super.key,
    required this.exercise,
    required this.isDark,
    this.showSetsReps = true,
  });

  @override
  Widget build(BuildContext context) {
    final name = exercise['name']?.toString() ?? 'Exercise';
    final videoUrl = WorkoutMediaUrls.normalize(
      exercise['demoVideoUrl']?.toString(),
    );
    final imageUrl = WorkoutMediaUrls.normalize(
      exercise['demoImageUrl']?.toString(),
    );

    String detail = '';
    if (showSetsReps) {
      final sets = exercise['sets'];
      final reps = exercise['reps'];
      if (sets != null || reps != null) {
        detail = '${sets ?? '-'} sets × ${reps ?? '-'} reps';
      }
      if (exercise['durationMinutes'] != null) {
        detail += '${detail.isEmpty ? '' : ' · '}${exercise['durationMinutes']} min';
      }
      if (exercise['restSeconds'] != null) {
        detail += '${detail.isEmpty ? '' : ' · '}${exercise['restSeconds']}s rest';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.isEmpty ? '• $name' : '• $name — $detail',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : CoachDashboardTheme.textPrimary,
            ),
          ),
          if (videoUrl != null) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => WorkoutMediaUrls.open(context, videoUrl),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_circle_fill_rounded,
                      size: 18,
                      color: CoachDashboardTheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Watch demo video',
                      style: TextStyle(
                        color: CoachDashboardTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor: CoachDashboardTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (imageUrl != null && videoUrl == null) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => WorkoutMediaUrls.open(context, imageUrl),
              child: Text(
                'View demo image',
                style: TextStyle(
                  color: CoachDashboardTheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
