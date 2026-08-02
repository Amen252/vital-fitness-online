import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';

/// iOS / iPadOS require a non-null [sharePositionOrigin] for the share sheet.
Rect _shareOrigin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box != null && box.hasSize && box.attached) {
    final size = box.size;
    if (size.width > 0 && size.height > 0) {
      return box.localToGlobal(Offset.zero) & size;
    }
  }
  final screen = MediaQuery.sizeOf(context);
  return Rect.fromCenter(
    center: Offset(screen.width / 2, screen.height / 2),
    width: 2,
    height: 2,
  );
}

Future<void> _shareText(
  BuildContext context, {
  required String text,
  required String subject,
}) async {
  final origin = _shareOrigin(context);
  try {
    await Share.share(
      text,
      subject: subject,
      sharePositionOrigin: origin,
    );
  } on PlatformException catch (e) {
    // Some iOS builds still reject the popover origin — fall back to clipboard.
    if (e.code == 'error' ||
        (e.message?.contains('sharePositionOrigin') ?? false)) {
      final urlMatch = RegExp(r'https?://\S+').firstMatch(text);
      final toCopy = urlMatch?.group(0) ?? text;
      await Clipboard.setData(ClipboardData(text: toCopy));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied — paste it anywhere to share'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    rethrow;
  }
}

/// Creates a share card and opens the system share sheet (falls back to clipboard).
Future<void> shareVitalCard(
  BuildContext context, {
  required String type,
  String? title,
  String? level,
}) async {
  final api = ApiService();
  final messenger = ScaffoldMessenger.of(context);

  try {
    final card = await api.createShareCard(type: type, title: title, level: level);
    final url = card['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw Exception('Share link was empty');
    }
    if (!context.mounted) return;

    await _shareText(
      context,
      text: 'Check out my Vital Fitness $type!\n$url',
      subject: 'Vital Fitness',
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(_friendlyShareError(e)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Future<void> shareInviteLink(BuildContext context) async {
  final api = ApiService();
  final messenger = ScaffoldMessenger.of(context);
  try {
    final invite = await api.getMyInvite();
    final url = invite['url']?.toString() ?? invite['shareUrl']?.toString() ?? '';
    if (url.isEmpty) throw Exception('Invite link unavailable');
    if (!context.mounted) return;

    await _shareText(
      context,
      text: 'Join me on Vital Fitness!\n$url',
      subject: 'Join Vital Fitness',
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(_friendlyShareError(e)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

String _friendlyShareError(Object error) {
  final message = error.toString();
  if (message.contains('sharePositionOrigin') || message.contains('PlatformException')) {
    return 'Unable to open the share sheet. The link was not shared.';
  }
  return ApiService.friendlyError(error);
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Copied to clipboard')),
  );
}

Future<void> offerShareWorkoutWin(
  BuildContext context, {
  String? workoutTitle,
}) async {
  final shouldShare = await showModalBottomSheet<bool>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Workout complete!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              workoutTitle == null || workoutTitle.isEmpty
                  ? 'Share this win with friends?'
                  : 'Share “$workoutTitle” with friends?',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Share this win'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
          ],
        ),
      );
    },
  );

  if (shouldShare == true && context.mounted) {
    await shareVitalCard(
      context,
      type: 'workout',
      title: workoutTitle,
    );
  }
}
