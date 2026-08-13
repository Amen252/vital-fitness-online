import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/scrollable_body.dart';
import '../../utils/date_utils.dart';
import 'widgets/coach_home/coach_dashboard_theme.dart';
import '../../widgets/silent_refresh.dart';

class UserClassDetailScreen extends StatefulWidget {
  final String classId;
  final Map<String, dynamic>? initialData;
  final VoidCallback? onUpdated;
  final VoidCallback? onViewWorkoutSchedule;

  const UserClassDetailScreen({
    super.key,
    required this.classId,
    this.initialData,
    this.onUpdated,
    this.onViewWorkoutSchedule,
  });

  @override
  State<UserClassDetailScreen> createState() => _UserClassDetailScreenState();
}

class _UserClassDetailScreenState extends State<UserClassDetailScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _classData;
  bool _isLoading = true;
  bool _isJoining = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _classData = widget.initialData;
    _load();
  }

  Future<void> _load({bool isRefresh = false}) async {
    if (!isRefresh || _classData == null) {
      setState(() {
        _isLoading = _classData == null;
        _errorMessage = null;
      });
    }
    try {
      final data = await _api.getUserClassDetail(widget.classId);
      if (mounted) {
        setState(() {
          _classData = data;
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

  Future<void> _joinClass() async {
    setState(() => _isJoining = true);
    try {
      final result = await _api.joinUserClass(widget.classId);
      if (mounted) {
        setState(() {
          _classData = result;
        });
        widget.onUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Joined class successfully!'),
            backgroundColor: CoachDashboardTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  String _formatDateTime(String? raw) {
    if (raw == null) return 'TBD';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour < 12 ? 'AM' : 'PM';
    return '${days[dt.weekday - 1]}, ${months[dt.month]} ${dt.day} · $h:$m $suffix';
  }

  String _formatOpensAt(String? raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      appBar: CoachDashboardTheme.coachAppBar(
        context: context,
        title: _classData?['title'] as String? ?? 'Class Details',
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _errorMessage != null && _classData == null
              ? ScrollableCenter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFFF6B6B), size: 48),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildContent(isDark),
    );
  }

  Widget _buildContent(bool isDark) {
    final data = _classData!;
    final title = data['title'] as String? ?? 'Group Class';
    final description = data['description'] as String? ?? '';
    final category = data['category'] as String? ?? 'General';
    final coachName = data['coach']?['name'] as String? ?? 'Your Coach';
    final coachEmail = data['coach']?['email'] as String? ?? '';
    final duration = data['durationMinutes'] as int? ?? 60;
    final status = data['status'] as String? ?? 'scheduled';
    final capacity = data['capacity'] as int? ?? 0;
    final enrolled = data['enrolledStudents'] as List<dynamic>? ?? [];
    final enrolledCount = data['enrolledCount'] as int? ?? enrolled.length;
    final isEnrolled = data['isEnrolled'] == true;
    final hasJoined = data['hasJoined'] == true;
    final sessionOpen = data['sessionOpen'] == true;
    final sessionOpensAt = _formatOpensAt(data['sessionOpensAt']?.toString());
    final workoutSchedules = List<dynamic>.from(data['workoutSchedules'] as List<dynamic>? ?? []);
    final upcomingWorkouts = workoutSchedules.where((s) {
      final start = parseApiDateTime((s as Map)['startDateTime']?.toString());
      return start != null && start.isAfter(DateTime.now());
    }).toList();

    final canJoin = !isEnrolled || (!hasJoined && sessionOpen);
    final joinLabel = !isEnrolled
        ? 'Join Class'
        : hasJoined
            ? 'Joined'
            : sessionOpen
                ? 'Join Session'
                : 'Enrolled';

    return SilentRefreshIndicator(
      onRefresh: () => _load(isRefresh: true),
      color: CoachDashboardTheme.primary,
      child: ListView(
        physics: dashboardScrollPhysics,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: CoachDashboardTheme.headerGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: CoachDashboardTheme.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('with $coachName', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('About This Class', isDark),
          const SizedBox(height: 10),
          _infoCard(
            isDark: isDark,
            child: Text(
              description.isNotEmpty
                  ? description
                  : 'Your coach has not added a description yet. Check back closer to the session.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.white70 : CoachDashboardTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Schedule', isDark),
          const SizedBox(height: 10),
          _infoCard(
            isDark: isDark,
            child: Column(
              children: [
                _detailRow(Icons.calendar_today_rounded, 'Date & time', _formatDateTime(data['date']?.toString())),
                const SizedBox(height: 10),
                _detailRow(Icons.timer_outlined, 'Duration', '$duration minutes'),
                if (sessionOpensAt.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _detailRow(Icons.schedule_rounded, 'Session opens', sessionOpensAt),
                ],
                const SizedBox(height: 10),
                _detailRow(Icons.flag_rounded, 'Status', status.toUpperCase()),
              ],
            ),
          ),
          if (upcomingWorkouts.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionTitle('Coach Workout Schedule', isDark),
            const SizedBox(height: 6),
            Text(
              'Workouts your coach assigned for this group.',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey),
            ),
            const SizedBox(height: 10),
            ...upcomingWorkouts.map((raw) {
              final s = Map<String, dynamic>.from(raw as Map);
              final title = s['title'] as String? ?? s['workoutTemplate']?['title'] as String? ?? 'Workout';
              final weeklyPlan = s['weeklyPlan'] as Map<String, dynamic>?;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: CoachDashboardTheme.cardDecoration(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                        if (weeklyPlan != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: CoachDashboardTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Weekly', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: CoachDashboardTheme.primary)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(formatApiDateTime(s['startDateTime']?.toString()), style: const TextStyle(fontSize: 12, color: CoachDashboardTheme.primary)),
                  ],
                ),
              );
            }),
            if (widget.onViewWorkoutSchedule != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onViewWorkoutSchedule!();
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: const Text('View Full Schedule'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CoachDashboardTheme.primary,
                    side: const BorderSide(color: CoachDashboardTheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
          _sectionTitle('Your Coach', isDark),
          const SizedBox(height: 10),
          _infoCard(
            isDark: isDark,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: CoachDashboardTheme.primary.withValues(alpha: 0.15),
                  child: Text(
                    coachName.isNotEmpty ? coachName[0].toUpperCase() : 'C',
                    style: const TextStyle(color: CoachDashboardTheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(coachName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      if (coachEmail.isNotEmpty)
                        Text(coachEmail, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Group Members', isDark),
          const SizedBox(height: 6),
          Text(
            '$enrolledCount${capacity > 0 ? ' / $capacity' : ''} enrolled',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey),
          ),
          const SizedBox(height: 10),
          if (enrolled.isEmpty)
            _infoCard(
              isDark: isDark,
              child: const Text('No members enrolled yet.', style: TextStyle(color: Colors.grey)),
            )
          else
            ...enrolled.map((student) {
              final s = student is Map ? student : <String, dynamic>{'_id': student};
              final name = s['name']?.toString() ?? 'Member';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: CoachDashboardTheme.cardDecoration(isDark),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF00D4AA).withValues(alpha: 0.15),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'M',
                        style: const TextStyle(color: Color(0xFF00D4AA), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    if (hasJoined && name == (data['coach']?['name'] ?? ''))
                      const SizedBox.shrink(),
                  ],
                ),
              );
            }),
          if (status != 'cancelled' && status != 'completed') ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isJoining || !canJoin || (isEnrolled && hasJoined))
                    ? null
                    : _joinClass,
                icon: _isJoining
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: const SizedBox.shrink(),
                      )
                    : Icon(
                        !isEnrolled
                            ? Icons.group_add_rounded
                            : hasJoined
                                ? Icons.check_circle_rounded
                                : Icons.play_circle_rounded,
                        size: 18,
                      ),
                label: Text(joinLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasJoined ? CoachDashboardTheme.success : CoachDashboardTheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: (hasJoined ? CoachDashboardTheme.success : CoachDashboardTheme.primary)
                      .withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Text(title, style: CoachDashboardTheme.sectionTitle(isDark));
  }

  Widget _infoCard({required bool isDark, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: child,
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: CoachDashboardTheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
