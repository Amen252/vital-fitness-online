import '../services/api_service.dart';

/// Helpers for parsing chat thread payloads from the API.
class CoachThreadUtils {
  static String threadId(Map<String, dynamic> thread) {
    return thread['assignmentId']?.toString()
        ?? thread['_id']?.toString()
        ?? '';
  }

  static String clientName(Map<String, dynamic> thread) {
    final user = thread['user'] ?? thread['counterpart'];
    if (user is Map) {
      return ApiService.displayName(Map<dynamic, dynamic>.from(user), fallback: 'Client');
    }
    return 'Client';
  }

  static String lastMessagePreview(Map<String, dynamic> thread) {
    final lastMessage = thread['lastMessage'];
    if (lastMessage is Map) {
      return lastMessage['body']?.toString() ?? 'No messages yet';
    }
    return 'No messages yet';
  }

  static bool isCoachMessage(Map<String, dynamic> message, String coachUserId) {
    final senderRole = message['senderRole']?.toString();
    if (senderRole == 'coach') return true;

    final sender = message['sender'];
    if (sender is Map) {
      return sender['_id']?.toString() == coachUserId || sender['role'] == 'coach';
    }
    return sender?.toString() == coachUserId;
  }

  static bool isFromCurrentUser(Map<String, dynamic> message, String currentUserId) {
    final sender = message['sender'];
    if (sender is Map) {
      return sender['_id']?.toString() == currentUserId;
    }
    return sender?.toString() == currentUserId;
  }

  static int unreadCount(Map<String, dynamic> thread) {
    final count = thread['unreadCount'];
    if (count is int) return count;
    if (count is num) return count.toInt();
    return 0;
  }

  static bool isUnreadIncomingMessage(Map<String, dynamic> message, String currentUserId) {
    if (message['read'] == true) return false;
    return !isFromCurrentUser(message, currentUserId);
  }
}
