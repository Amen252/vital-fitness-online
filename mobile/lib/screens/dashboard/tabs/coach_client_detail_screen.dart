import 'package:flutter/material.dart';
import '../../../widgets/scrollable_body.dart';
import '../../../services/api_service.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';
import '../chat_screen.dart';
import 'coach_progress_tab.dart';

class CoachClientDetailScreen extends StatefulWidget {
  final Map<String, dynamic> clientData;

  const CoachClientDetailScreen({super.key, required this.clientData});

  @override
  State<CoachClientDetailScreen> createState() => _CoachClientDetailScreenState();
}

class _CoachClientDetailScreenState extends State<CoachClientDetailScreen> {
  final ApiService _api = ApiService();
  late Map<String, dynamic> _clientData;
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _availableClasses = [];
  bool _loadingGroups = false;
  bool _updatingGroup = false;

  @override
  void initState() {
    super.initState();
    _clientData = Map<String, dynamic>.from(widget.clientData);
    _groups = _parseGroups(_clientData['groups']);
    _loadGroupData();
  }

  String? get _clientId =>
      _clientData['user']?['_id']?.toString() ?? _clientData['user']?.toString();

  List<Map<String, dynamic>> _parseGroups(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((g) => Map<String, dynamic>.from(g as Map)).toList();
  }

  Future<void> _loadGroupData() async {
    final clientId = _clientId;
    if (clientId == null || clientId.isEmpty) return;

    setState(() => _loadingGroups = true);
    try {
      final results = await Future.wait([
        _api.getCoachClientDetail(clientId),
        _api.getCoachClasses(),
      ]);
      if (!mounted) return;
      final detail = Map<String, dynamic>.from(results[0] as Map);
      final classes = (results[1] as List)
          .map((c) => Map<String, dynamic>.from(c as Map))
          .where((c) {
            final status = c['status']?.toString() ?? '';
            return status != 'completed' && status != 'cancelled';
          })
          .toList();
      setState(() {
        _clientData = {..._clientData, ...detail};
        _groups = _parseGroups(detail['groups']);
        _availableClasses = classes;
        _loadingGroups = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingGroups = false);
    }
  }

  Future<void> _changeGroup({String? classId, String? fromClassId}) async {
    final clientId = _clientId;
    if (clientId == null) return;

    setState(() => _updatingGroup = true);
    try {
      final result = await _api.changeClientGroup(
        clientId,
        classId: classId,
        fromClassId: fromClassId,
      );
      if (!mounted) return;
      setState(() {
        _groups = _parseGroups(result['groups']);
        _updatingGroup = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Group updated'),
          backgroundColor: CoachDashboardTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _updatingGroup = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiService.friendlyError(e)),
          backgroundColor: CoachDashboardTheme.danger,
        ),
      );
    }
  }

  Future<void> _showAssignOrChangeGroup({String? fromClassId}) async {
    final currentIds = _groups.map((g) => g['_id']?.toString()).whereType<String>().toSet();
    final options = _availableClasses.where((c) {
      final id = c['_id']?.toString() ?? '';
      if (id.isEmpty || id == fromClassId) return false;
      // When moving from a specific group, any other group is valid.
      // When assigning, skip groups the client is already in.
      if (fromClassId != null) return true;
      return !currentIds.contains(id);
    }).toList();

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other groups available. Create a group first.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181B24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      fromClassId == null ? 'Assign to Group' : 'Move to Another Group',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final cls = options[i];
                    final id = cls['_id']?.toString() ?? '';
                    final title = cls['title']?.toString() ?? 'Group';
                    final category = cls['category']?.toString() ?? '';
                    final enrolled = cls['enrolledCount'] as int? ??
                        (cls['enrolledStudents'] as List?)?.length ??
                        0;
                    final capacity = cls['capacity'] as int? ?? 20;
                    final full = enrolled >= capacity;
                    return ListTile(
                      enabled: !full,
                      leading: CircleAvatar(
                        backgroundColor: CoachDashboardTheme.primary.withValues(alpha: 0.12),
                        child: const Icon(Icons.groups_rounded, color: CoachDashboardTheme.primary),
                      ),
                      title: Text(title),
                      subtitle: Text(
                        full
                            ? '$category · Full ($enrolled/$capacity)'
                            : '$category · $enrolled/$capacity enrolled',
                      ),
                      trailing: full ? null : const Icon(Icons.chevron_right_rounded),
                      onTap: full ? null : () => Navigator.pop(ctx, id),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    await _changeGroup(classId: selected, fromClassId: fromClassId);
  }

  Future<void> _confirmRemoveFromGroup(Map<String, dynamic> group) async {
    final title = group['title']?.toString() ?? 'this group';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Group'),
        content: Text('Remove this client from "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: CoachDashboardTheme.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _changeGroup(classId: null, fromClassId: group['_id']?.toString());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = _clientData['user'] ?? {};
    final userMap = user is Map ? Map<dynamic, dynamic>.from(user) : null;
    final name = ApiService.displayName(userMap, fallback: 'Client');
    final email = ApiService.displayIdentity(userMap);
    final profile = user['profile'] ?? {};
    final goals = profile['goals'] as List<dynamic>? ?? [];
    final assignmentId = _clientData['_id']?.toString() ?? '';

    return CoachPage(
      title: name,
      body: ListView(
        physics: dashboardScrollPhysics,
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: CoachDashboardTheme.cardDecoration(isDark),
            child: Column(
              children: [
                CoachDashboardTheme.avatarBox(
                  initial: name.isNotEmpty ? name[0].toUpperCase() : 'C',
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(email, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Message',
                  color: CoachDashboardTheme.pink,
                  onTap: () async {
                    final coach = await ApiService().getMe();
                    if (!context.mounted || coach == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => ChatScreen(
                          assignmentId: assignmentId,
                          coachName: name,
                          currentUser: coach,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.show_chart_rounded,
                  label: 'Progress',
                  color: CoachDashboardTheme.success,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => CoachProgressTab(
                          clientId: user['_id']?.toString(),
                          clientName: name,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildGroupSection(isDark),
          const SizedBox(height: 24),
          const Text('Fitness Goals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: CoachDashboardTheme.cardDecoration(isDark),
            child: goals.isEmpty
                ? const Text('No fitness goals set by the user.', style: TextStyle(color: Colors.grey))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: goals.asMap().entries.map((entry) {
                      final i = entry.key;
                      final g = entry.value.toString();
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(Icons.flag_rounded, color: CoachDashboardTheme.accent.withValues(alpha: 0.9), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(g, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                          if (i < goals.length - 1) const Divider(height: 1),
                        ],
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),
          const Text('Client Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: CoachDashboardTheme.cardDecoration(isDark),
            child: Column(
              children: [
                _InfoRow(label: 'Age', value: profile['age']?.toString() ?? 'Not specified'),
                const Divider(height: 24),
                _InfoRow(label: 'Height', value: profile['heightCm'] != null ? '${profile['heightCm']} cm' : 'Not specified'),
                const Divider(height: 24),
                _InfoRow(label: 'Weight', value: profile['weightKg'] != null ? '${profile['weightKg']} kg' : 'Not specified'),
                const Divider(height: 24),
                _InfoRow(label: 'Experience', value: profile['experience'] ?? 'Not specified'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Group Class', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (_loadingGroups || _updatingGroup)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: CoachDashboardTheme.primary),
              )
            else
              TextButton.icon(
                onPressed: () => _showAssignOrChangeGroup(),
                icon: Icon(_groups.isEmpty ? Icons.group_add_rounded : Icons.swap_horiz_rounded, size: 18),
                label: Text(_groups.isEmpty ? 'Assign' : 'Change'),
                style: TextButton.styleFrom(foregroundColor: CoachDashboardTheme.primary),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: CoachDashboardTheme.cardDecoration(isDark),
          child: _groups.isEmpty
              ? const Text(
                  'Not assigned to any group yet.',
                  style: TextStyle(color: Colors.grey),
                )
              : Column(
                  children: _groups.asMap().entries.map((entry) {
                    final i = entry.key;
                    final group = entry.value;
                    final title = group['title']?.toString() ?? 'Group';
                    final category = group['category']?.toString() ?? '';
                    final groupId = group['_id']?.toString();
                    return Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: CoachDashboardTheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.groups_rounded, color: CoachDashboardTheme.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  if (category.isNotEmpty)
                                    Text(category, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              enabled: !_updatingGroup,
                              onSelected: (value) {
                                if (value == 'move') {
                                  _showAssignOrChangeGroup(fromClassId: groupId);
                                } else if (value == 'remove') {
                                  _confirmRemoveFromGroup(group);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'move', child: Text('Move to another group')),
                                PopupMenuItem(value: 'remove', child: Text('Remove from group')),
                              ],
                              icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white54 : Colors.grey),
                            ),
                          ],
                        ),
                        if (i < _groups.length - 1) const Divider(height: 24),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      onPressed: onTap,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
