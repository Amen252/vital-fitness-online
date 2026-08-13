/// Labels for fitness-class / group member counts from API (`enrolledCount`
/// or `enrolledStudents.length`). Always derived from live backend data.

int groupEnrolledCount(dynamic cls) {
  if (cls is! Map) return 0;
  final enrolledCount = cls['enrolledCount'];
  if (enrolledCount is num) return enrolledCount.toInt();
  final students = cls['enrolledStudents'];
  if (students is List) return students.length;
  return 0;
}

String groupMemberCountLabel(int count) {
  return count == 1 ? '1 Member' : '$count Members';
}

String groupTitleWithMembers(String title, int count) {
  final safeTitle = title.trim().isEmpty ? 'Group' : title.trim();
  return '$safeTitle — ${groupMemberCountLabel(count)}';
}

String groupTitleFromClass(dynamic cls, {String fallback = 'Group'}) {
  if (cls is! Map) return fallback;
  final title = cls['title']?.toString() ?? fallback;
  return groupTitleWithMembers(title, groupEnrolledCount(cls));
}
