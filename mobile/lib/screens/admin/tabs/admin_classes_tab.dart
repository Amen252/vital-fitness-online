import 'package:flutter/material.dart';
import '../../dashboard/widgets/coach_home/coach_dashboard_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/api_service.dart';
import '../../../widgets/scrollable_body.dart';
import '../widgets/admin_management_widgets.dart';

class AdminClassesTab extends StatefulWidget {
  final User adminUser;

  static final globalRefreshKey = GlobalKey<AdminClassesTabState>();

  const AdminClassesTab({super.key, required this.adminUser});

  @override
  AdminClassesTabState createState() => AdminClassesTabState();
}

class AdminClassesTabState extends State<AdminClassesTab> {
  final ApiService _apiService = ApiService();
  List<dynamic> _classes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final showFullLoader = _classes.isEmpty;
    setState(() {
      if (showFullLoader) _isLoading = true;
      _errorMessage = null;
    });
    try {
      final classes = await _apiService.getAdminClasses();
      if (mounted) {
        setState(() {
          _classes = classes;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ApiService.friendlyError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? raw) {
    final dt = DateTime.tryParse(raw ?? '');
    if (dt == null) return 'TBD';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour < 12 ? 'AM' : 'PM';
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day} · $h:$m $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorMessage != null) {
      return ScrollableCenter(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: refresh, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_classes.isEmpty) {
      return AdminEmptyState(
        isDark: isDark,
        icon: Icons.fitness_center_outlined,
        message: 'No classes scheduled',
        subtitle: 'Group classes created by coaches will appear here.',
      );
    }

    return ListView.builder(
      physics: dashboardScrollPhysics,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _classes.length,
      itemBuilder: (context, index) {
        final cls = _classes[index];
        final title = cls['title'] ?? 'Untitled';
        final desc = cls['description'] ?? '';
        final capacity = cls['capacity'] ?? 0;
        final enrolled = cls['enrolledCount'] as int? ?? (cls['enrolledStudents'] as List?)?.length ?? 0;
        final coachName = cls['coach'] is Map ? cls['coach']['name'] ?? 'Coach' : 'Coach';
        final status = cls['status'] ?? 'scheduled';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: CoachDashboardTheme.cardDecoration(isDark),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CoachDashboardTheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fitness_center_rounded, color: CoachDashboardTheme.primary),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 6),
                Text('Coach: $coachName · ${_formatDate(cls['date'] as String?)}'),
                Text('$enrolled / $capacity enrolled · ${status.toString()}'),
              ],
            ),
          ),
        );
      },
    );
  }
}
