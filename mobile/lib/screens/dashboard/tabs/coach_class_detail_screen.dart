import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../widgets/scrollable_body.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';
import 'workout_form_sheet.dart';
import '../../../widgets/silent_refresh.dart';

class CoachClassDetailScreen extends StatefulWidget {
  final Map<String, dynamic> classData;
  final List<dynamic> clients;
  final VoidCallback onUpdated;

  const CoachClassDetailScreen({
    super.key,
    required this.classData,
    required this.clients,
    required this.onUpdated,
  });

  @override
  State<CoachClassDetailScreen> createState() => _CoachClassDetailScreenState();
}

class _CoachClassDetailScreenState extends State<CoachClassDetailScreen>
    with WidgetsBindingObserver {
  final ApiService _api = ApiService();
  late Map<String, dynamic> _classData;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _classData = Map<String, dynamic>.from(widget.classData);
    _refreshClass();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshClass();
  }

  /// Re-reads the class from the API so enrolled client names, photos and
  /// attendance always reflect the current database state.
  Future<void> _refreshClass() async {
    final id = _classData['_id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      final results = await Future.wait<dynamic>([
        _api.getCoachClass(id),
        _api.getCoachClients(light: true),
      ]);
      final fresh = Map<String, dynamic>.from(results[0] as Map);
      final clients = List<dynamic>.from(results[1] as List);

      // Reconcile populated enrollment records with the live clients response.
      // This also repairs old class snapshots that contain only a user ID.
      final usersById = <String, Map<dynamic, dynamic>>{};
      for (final entry in clients) {
        if (entry is! Map || entry['user'] is! Map) continue;
        final user = Map<dynamic, dynamic>.from(entry['user'] as Map);
        final userId = user['_id']?.toString();
        if (userId != null && userId.isNotEmpty) usersById[userId] = user;
      }

      final enrolled = List<dynamic>.from(
        fresh['enrolledStudents'] as List<dynamic>? ?? const [],
      );
      fresh['enrolledStudents'] = enrolled.map((entry) {
        final existing = entry is Map
            ? Map<dynamic, dynamic>.from(entry)
            : <dynamic, dynamic>{'_id': entry};
        final userId = existing['_id']?.toString() ?? entry?.toString() ?? '';
        final liveUser = usersById[userId];
        return liveUser == null
            ? existing
            : <dynamic, dynamic>{...existing, ...liveUser};
      }).toList();

      if (mounted) setState(() => _classData = fresh);
    } catch (_) {
      // Keep showing the data we were handed if the refresh fails.
    }
  }

  List<dynamic> get _enrolled =>
      _classData['enrolledStudents'] as List<dynamic>? ?? [];

  int get _capacity => (_classData['capacity'] as num?)?.toInt() ?? 20;

  Map<String, bool> get _attendanceMap {
    final map = <String, bool>{};
    final attendance = _classData['attendance'] as List<dynamic>? ?? [];
    for (final entry in attendance) {
      final student = entry['student'];
      final id = student is Map
          ? student['_id']?.toString()
          : student?.toString();
      if (id != null) map[id] = entry['present'] != false;
    }
    return map;
  }

  Future<void> _enrollClient() async {
    final enrolledIds = _enrolled
        .map((s) => s is Map ? s['_id']?.toString() : s?.toString())
        .whereType<String>()
        .toSet();

    // Always load the latest approved clients so newly approved users appear immediately.
    List<dynamic> clients = widget.clients;
    try {
      clients = await _api.getCoachClients(light: true);
    } catch (_) {
      // Fall back to the snapshot passed from the classes tab.
    }

    final available = clients.where((c) {
      final id = c['user']?['_id']?.toString();
      return id != null && !enrolledIds.contains(id);
    }).toList();

    if (!mounted) return;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No approved clients available. Approve a request first, then add them here.',
          ),
          backgroundColor: CoachDashboardTheme.warning,
        ),
      );
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Add to class'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Only approved clients are listed.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? Colors.white60
                        : CoachDashboardTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: available.length,
                    itemBuilder: (context, index) {
                      final client = available[index];
                      final userMap = client['user'] is Map
                          ? Map<dynamic, dynamic>.from(client['user'] as Map)
                          : null;
                      final name = ApiService.displayName(
                        userMap,
                        fallback: 'Client',
                      );
                      final email = ApiService.displayIdentity(userMap);
                      final id = client['user']?['_id']?.toString() ?? '';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: CoachDashboardTheme.primary
                              .withValues(alpha: 0.12),
                          child: Text(
                            name.toString().isNotEmpty
                                ? name.toString()[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                              color: CoachDashboardTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(name.toString()),
                        subtitle: email.toString().isNotEmpty
                            ? Text(email.toString())
                            : null,
                        onTap: () => Navigator.pop(ctx, id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selected == null) return;

    setState(() => _actionBusy = true);
    try {
      final updated = await _api.enrollInCoachClass(
        _classData['_id']?.toString() ?? '',
        selected,
      );
      if (!mounted) return;
      setState(() => _classData = updated);
      await _refreshClass();
      widget.onUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client added to class.'),
            backgroundColor: CoachDashboardTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.friendlyError(e)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _unenroll(String userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from class?'),
        content: Text(
          'Remove $name from this class? They will remain your approved client.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: CoachDashboardTheme.danger),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final updated = await _api.unenrollFromCoachClass(
        _classData['_id']?.toString() ?? '',
        userId,
      );
      setState(() => _classData = updated);
      await _refreshClass();
      widget.onUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name removed from class.'),
            backgroundColor: CoachDashboardTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.friendlyError(e)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _moveClient(String userId, String name) async {
    final currentId = _classData['_id']?.toString() ?? '';
    List<Map<String, dynamic>> options = [];
    try {
      final classes = await _api.getCoachClasses();
      options = classes.map((c) => Map<String, dynamic>.from(c as Map)).where((
        c,
      ) {
        final id = c['_id']?.toString() ?? '';
        final status = c['status']?.toString() ?? '';
        return id.isNotEmpty &&
            id != currentId &&
            status != 'completed' &&
            status != 'cancelled';
      }).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.friendlyError(e)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (options.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No other groups available')),
        );
      }
      return;
    }

    if (!mounted) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Move $name'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (_, i) {
              final cls = options[i];
              final id = cls['_id']?.toString() ?? '';
              final title = cls['title']?.toString() ?? 'Group';
              final enrolled =
                  cls['enrolledCount'] as int? ??
                  (cls['enrolledStudents'] as List?)?.length ??
                  0;
              final capacity = cls['capacity'] as int? ?? 20;
              final full = enrolled >= capacity;
              return ListTile(
                enabled: !full,
                title: Text(title),
                subtitle: Text(
                  full
                      ? 'Full ($enrolled/$capacity)'
                      : '$enrolled/$capacity enrolled',
                ),
                onTap: full ? null : () => Navigator.pop(ctx, id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected == null) return;

    setState(() => _actionBusy = true);
    try {
      await _api.changeClientGroup(
        userId,
        classId: selected,
        fromClassId: currentId,
      );
      final classes = await _api.getCoachClasses();
      final match = classes.cast<dynamic>().where(
        (c) => (c as Map)['_id']?.toString() == currentId,
      );
      if (!mounted) return;
      setState(() {
        if (match.isNotEmpty) {
          _classData = Map<String, dynamic>.from(match.first as Map);
        }
      });
      await _refreshClass();
      if (!mounted) return;
      widget.onUpdated();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name moved to another group'),
          backgroundColor: CoachDashboardTheme.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.friendlyError(e)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _toggleAttendance(String userId, bool present) async {
    try {
      final updated = await _api.markClassAttendance(
        _classData['_id']?.toString() ?? '',
        userId,
        !present,
      );
      setState(() => _classData = updated);
      await _refreshClass();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.friendlyError(e)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _assignGroupWorkout() async {
    final classId = _classData['_id']?.toString();
    if (classId == null || classId.isEmpty) return;
    final title = _classData['title']?.toString() ?? 'Group';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WorkoutFormSheet(
        targetLabel: title,
        fitnessClassId: classId,
        apiService: _api,
        onSaved: () {
          widget.onUpdated();
        },
      ),
    );
  }

  Future<void> _editClass() async {
    final titleCtrl = TextEditingController(
      text: _classData['title']?.toString() ?? '',
    );
    final descCtrl = TextEditingController(
      text: _classData['description']?.toString() ?? '',
    );
    final capacityCtrl = TextEditingController(text: '$_capacity');
    String category = _classData['category']?.toString() ?? 'General';
    String status = _classData['status']?.toString() ?? 'scheduled';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Class'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                TextField(
                  controller: capacityCtrl,
                  decoration: const InputDecoration(labelText: 'Capacity'),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items:
                      [
                            'General',
                            'Yoga',
                            'HIIT',
                            'Strength',
                            'Cardio',
                            'Flexibility',
                          ]
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                  onChanged: (v) =>
                      setDialogState(() => category = v ?? category),
                ),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: ['scheduled', 'active', 'completed', 'cancelled']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => status = v ?? status),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    try {
      final updated = await _api
          .updateCoachClass(_classData['_id']?.toString() ?? '', {
            'title': titleCtrl.text.trim(),
            'description': descCtrl.text.trim(),
            'capacity': int.tryParse(capacityCtrl.text) ?? _capacity,
            'category': category,
            'status': status,
          });
      setState(() => _classData = updated);
      await _refreshClass();
      widget.onUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.friendlyError(e)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = _classData['title']?.toString() ?? 'Class';
    final date = DateTime.tryParse(_classData['date']?.toString() ?? '');
    final dateStr = date != null
        ? '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : 'TBD';

    return CoachPage(
      title: title,
      actions: [
        IconButton(
          tooltip: 'Assign workout to group',
          icon: const Icon(Icons.fitness_center_rounded),
          onPressed: _assignGroupWorkout,
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: _editClass,
        ),
      ],
      floatingActionButton: _enrolled.length < _capacity
          ? FloatingActionButton.extended(
              onPressed: _actionBusy ? null : _enrollClient,
              icon: _actionBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: const SizedBox.shrink(),
                    )
                  : const Icon(Icons.person_add_rounded),
              label: Text(_actionBusy ? 'Working…' : 'Add to Class'),
              backgroundColor: CoachDashboardTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      body: SilentRefreshIndicator(
              onRefresh: _refreshClass,
              child: ListView(
                physics: dashboardScrollPhysics,
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: CoachDashboardTheme.cardDecoration(isDark),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _classData['category']?.toString() ?? 'General',
                          style: TextStyle(
                            color: CoachDashboardTheme.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _classData['description']?.toString() ?? '',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(dateStr),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_enrolled.length} / $_capacity enrolled · Status: ${_classData['status']}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Enrolled Clients',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_enrolled.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.people_outline_rounded,
                              size: 40,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No clients enrolled yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Add an approved client to this class to get started.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._enrolled.map((student) {
                      final s = student is Map
                          ? Map<dynamic, dynamic>.from(student)
                          : <dynamic, dynamic>{'_id': student};
                      final id = s['_id']?.toString() ?? '';
                      // Show the real full name only — never the email address.
                      final rawName = ((s['full_name'] ?? s['name']) ?? '')
                          .toString()
                          .trim();
                      final name = rawName.isNotEmpty ? rawName : 'Member';
                      final photoUrl = (s['avatar'] ?? s['photoUrl'])
                          ?.toString();
                      final present = _attendanceMap[id] ?? false;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: ProfileAvatar(
                            name: name,
                            photoUrl: photoUrl,
                            radius: 20,
                            backgroundColor: CoachDashboardTheme.primary,
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            present ? 'Present' : 'Attendance not marked',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Mark attendance',
                                icon: Icon(
                                  present
                                      ? Icons.check_circle
                                      : Icons.check_circle_outline,
                                  color: present ? Colors.green : Colors.grey,
                                ),
                                onPressed: () => _toggleAttendance(id, present),
                              ),
                              IconButton(
                                tooltip: 'Move to another class',
                                icon: const Icon(
                                  Icons.swap_horiz_rounded,
                                  color: CoachDashboardTheme.primary,
                                ),
                                onPressed: _actionBusy
                                    ? null
                                    : () => _moveClient(id, name),
                              ),
                              IconButton(
                                tooltip: 'Remove from class',
                                icon: const Icon(
                                  Icons.person_remove,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _unenroll(id, name),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
