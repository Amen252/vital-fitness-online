import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../widgets/scrollable_body.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';

class CoachProgressTab extends StatefulWidget {
  final String? clientId;
  final String? clientName;

  const CoachProgressTab({super.key, this.clientId, this.clientName});

  @override
  State<CoachProgressTab> createState() => _CoachProgressTabState();
}

class _ClientWorkoutStats {
  final int complete;
  final int notMet;
  final int open;

  const _ClientWorkoutStats({
    this.complete = 0,
    this.notMet = 0,
    this.open = 0,
  });

  int get total => complete + notMet + open;

  int get completePct => total == 0 ? 0 : ((complete / total) * 100).round();
  int get notMetPct => total == 0 ? 0 : ((notMet / total) * 100).round();
  int get openPct => total == 0 ? 0 : (100 - completePct - notMetPct).clamp(0, 100);
}

class _CoachProgressTabState extends State<CoachProgressTab> {
  static const _completeColor = Color(0xFF34C759);
  static const _notMetColor = Color(0xFFFF9500);
  static const _openColor = Color(0xFF8E8E93);

  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _detailLoading = false;
  String _errorMessage = '';

  List<Map<String, dynamic>> _clients = [];
  final Map<String, _ClientWorkoutStats> _statsByClientId = {};

  Map<String, dynamic>? _selectedClient;
  Map<String, dynamic>? _workoutProgress;
  Map<String, dynamic>? _dietProgress;
  List<Map<String, dynamic>> _dailyTrackings = [];

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  String? _userIdOf(Map<String, dynamic> client) {
    final user = client['user'];
    if (user is Map) return user['_id']?.toString();
    return user?.toString();
  }

  String _clientNameOf(Map<String, dynamic> client) {
    final user = client['user'];
    if (user is Map) {
      return ApiService.displayName(user, fallback: 'Client');
    }
    return 'Client';
  }

  String? _photoUrlOf(Map<String, dynamic> client) {
    final user = client['user'];
    if (user is! Map) return null;
    final avatar = user['avatar'] ?? user['photoUrl'] ?? user['photo'];
    return avatar?.toString();
  }

  Map<String, dynamic> _clientProfile(Map<String, dynamic> client) {
    final user = client['user'];
    if (user is! Map) return {};
    final clientData = user['clientData'];
    if (clientData is Map) return Map<String, dynamic>.from(clientData);
    final profile = user['profile'];
    if (profile is Map) return Map<String, dynamic>.from(profile);
    return {};
  }

  String _fitnessGoalLabel(String? goal) {
    switch (goal) {
      case 'lose_weight':
        return 'Weight Loss';
      case 'gain_muscle':
        return 'Muscle Gain';
      case 'maintain':
        return 'Fitness / Maintain';
      case 'other':
        return 'Other';
      default:
        final text = (goal ?? '').trim();
        return text.isEmpty ? 'Not set' : text;
    }
  }

  _ClientWorkoutStats _statsFromWorkoutProgress(Map<String, dynamic> data) {
    final summary = data['summary'] is Map
        ? Map<String, dynamic>.from(data['summary'] as Map)
        : <String, dynamic>{};
    final complete = (summary['completed'] as num?)?.toInt() ?? 0;
    final missed = (summary['missed'] as num?)?.toInt() ?? 0;
    final pending = (summary['pending'] as num?)?.toInt() ?? 0;
    // Treat remaining open assignments as pending (and any leftover vs total).
    final total = (summary['totalAssignments'] as num?)?.toInt() ?? (complete + missed + pending);
    final open = (pending + (total - complete - missed - pending)).clamp(0, total);
    return _ClientWorkoutStats(complete: complete, notMet: missed, open: open);
  }

  Future<void> _loadClients() async {
    final showFullLoader = _clients.isEmpty;
    if (mounted) {
      setState(() {
        if (showFullLoader) _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final results = await Future.wait([
        _apiService.getCoachClients(),
        _apiService.getCoachDashboard().catchError((_) => null),
      ]);

      final rawClients = results[0] as List<dynamic>;
      final dash = results[1] as Map<String, dynamic>?;

      final clients = rawClients
          .whereType<Map>()
          .map((c) => Map<String, dynamic>.from(c))
          .toList();

      // Only assigned clients from /coach/clients.
      var filtered = clients;
      if (widget.clientId != null) {
        filtered = clients.where((client) {
          final userId = _userIdOf(client);
          final assignmentId = client['_id']?.toString();
          return userId == widget.clientId || assignmentId == widget.clientId;
        }).toList();
      }

      final trackings = ((dash?['clientProgress'] as Map?)?['dailyTrackings'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];

      final stats = <String, _ClientWorkoutStats>{};
      await Future.wait(filtered.map((client) async {
        final userId = _userIdOf(client);
        if (userId == null || userId.isEmpty) return;
        try {
          final progress = await _apiService.getClientWorkoutProgress(userId, days: 90);
          stats[userId] = _statsFromWorkoutProgress(progress);
        } catch (_) {
          stats[userId] = const _ClientWorkoutStats();
        }
      }));

      if (!mounted) return;
      setState(() {
        _clients = filtered;
        _statsByClientId
          ..clear()
          ..addAll(stats);
        _dailyTrackings = trackings;
        _isLoading = false;
      });

      if (filtered.isEmpty) return;

      // Deep-link from client detail → open that client's overview.
      if (widget.clientId != null) {
        final preferred = filtered.firstWhere(
          (c) => _userIdOf(c) == widget.clientId || c['_id']?.toString() == widget.clientId,
          orElse: () => filtered.first,
        );
        await _openClientDetail(preferred);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ApiService.friendlyError(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openClientDetail(Map<String, dynamic> client) async {
    final userId = _userIdOf(client);
    if (userId == null || userId.isEmpty) return;

    setState(() {
      _selectedClient = client;
      _detailLoading = true;
      _workoutProgress = null;
      _dietProgress = null;
      _errorMessage = '';
    });

    try {
      final results = await Future.wait([
        _apiService.getClientWorkoutProgress(userId, days: 30).catchError((_) => <String, dynamic>{}),
        _apiService.getClientDietProgress(userId, days: 30).catchError((_) => <String, dynamic>{}),
        _apiService.getCoachClientDetail(userId).catchError((_) => <String, dynamic>{}),
      ]);

      if (!mounted) return;

      final detail = Map<String, dynamic>.from(results[2] as Map);
      final merged = detail.isEmpty ? client : {...client, ...detail};
      final workout = Map<String, dynamic>.from(results[0] as Map);

      setState(() {
        _selectedClient = merged;
        _workoutProgress = workout;
        _dietProgress = Map<String, dynamic>.from(results[1] as Map);
        _statsByClientId[userId] = _statsFromWorkoutProgress(workout);
        _detailLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ApiService.friendlyError(e);
          _detailLoading = false;
        });
      }
    }
  }

  void _closeDetail() {
    if (widget.clientId != null) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _selectedClient = null;
      _workoutProgress = null;
      _dietProgress = null;
      _detailLoading = false;
    });
  }

  int _computeStreak(List<dynamic> history) {
    final days = <String>{};
    for (final item in history) {
      if (item is! Map) continue;
      if (item['status']?.toString() != 'completed') continue;
      final raw = item['completedAt'] ??
          item['reviewedAt'] ??
          item['submittedAt'] ??
          item['updatedAt'] ??
          item['createdAt'];
      final dt = DateTime.tryParse(raw?.toString() ?? '');
      if (dt == null) continue;
      final local = dt.toLocal();
      days.add(
        '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}',
      );
    }
    if (days.isEmpty) return 0;

    DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    String key(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final today = dayOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    DateTime? cursor =
        days.contains(key(today)) ? today : (days.contains(key(yesterday)) ? yesterday : null);
    if (cursor == null) return 0;

    var streak = 0;
    while (days.contains(key(cursor!))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int? _latestStepsFor(String userId) {
    final matches = _dailyTrackings.where((t) {
      final uid = t['user_id'];
      if (uid is Map) return uid['_id']?.toString() == userId;
      return uid?.toString() == userId;
    }).toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) {
      final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(1970);
      final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(1970);
      return db.compareTo(da);
    });
    return (matches.first['steps'] as num?)?.toInt();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showingDetail = _selectedClient != null;
    final title = showingDetail
        ? '${_clientNameOf(_selectedClient!)} · Progress'
        : (widget.clientName != null
            ? '${widget.clientName} · Client Progress'
            : 'Client Progress');

    return CoachPage(
      title: title,
      actions: [
        if (showingDetail)
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Back to list',
            onPressed: _closeDetail,
          ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _isLoading || _detailLoading
              ? null
              : () {
                  if (showingDetail && _selectedClient != null) {
                    _openClientDetail(_selectedClient!);
                  } else {
                    _loadClients();
                  }
                },
        ),
      ],
      body: _isLoading
          ? const ScrollableCenter(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty && _clients.isEmpty
              ? ScrollableCenter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorMessage, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadClients, child: const Text('Retry')),
                    ],
                  ),
                )
              : _clients.isEmpty
                  ? ScrollableCenter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 64,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No assigned clients yet.',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Client Progress only shows people assigned to you.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black45,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : showingDetail
                      ? (_detailLoading
                          ? const ScrollableCenter(child: CircularProgressIndicator())
                          : ListView(
                              physics: dashboardScrollPhysics,
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                              children: [_buildClientDetail(isDark)],
                            ))
                      : _buildClientList(isDark),
    );
  }

  Widget _buildClientList(bool isDark) {
    final divider = Divider(
      height: 1,
      thickness: 0.5,
      color: isDark ? Colors.white12 : const Color(0xFFE5E5EA),
    );

    return ListView.separated(
      physics: dashboardScrollPhysics,
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
      itemCount: _clients.length,
      separatorBuilder: (_, __) => divider,
      itemBuilder: (context, index) {
        final client = _clients[index];
        return _buildClientRow(client, isDark);
      },
    );
  }

  Widget _buildClientRow(Map<String, dynamic> client, bool isDark) {
    final name = _clientNameOf(client);
    final userId = _userIdOf(client) ?? '';
    final stats = _statsByClientId[userId] ?? const _ClientWorkoutStats();
    final nameColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final chevronColor = isDark ? Colors.white38 : const Color(0xFFC7C7CC);

    return InkWell(
      onTap: () => _openClientDetail(client),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ProfileAvatar(
              name: name,
              photoUrl: _photoUrlOf(client),
              radius: 28,
              backgroundColor: CoachDashboardTheme.primary.withValues(alpha: 0.12),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: nameColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _statLabel(
                          'Complete',
                          stats.completePct,
                          stats.complete,
                          _completeColor,
                        ),
                      ),
                      Expanded(
                        child: _statLabel(
                          'Not Met',
                          stats.notMetPct,
                          stats.notMet,
                          _notMetColor,
                        ),
                      ),
                      Expanded(
                        child: _statLabel(
                          'Open',
                          stats.openPct,
                          stats.open,
                          _openColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _segmentedBar(stats),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: chevronColor, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _statLabel(String label, int pct, int count, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$pct% ($count)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _segmentedBar(_ClientWorkoutStats stats) {
    final total = stats.total;
    if (total <= 0) {
      return Container(
        height: 6,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }

    // Use flex counts so the bar matches Complete / Not Met / Open.
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            if (stats.complete > 0)
              Expanded(
                flex: stats.complete,
                child: Container(color: _completeColor),
              ),
            if (stats.notMet > 0)
              Expanded(
                flex: stats.notMet,
                child: Container(color: _notMetColor),
              ),
            if (stats.open > 0)
              Expanded(
                flex: stats.open,
                child: Container(color: _openColor),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientDetail(bool isDark) {
    final client = _selectedClient!;
    final userId = _userIdOf(client) ?? '';
    final profile = _clientProfile(client);
    final snapshot = client['snapshot'] is Map
        ? Map<String, dynamic>.from(client['snapshot'] as Map)
        : <String, dynamic>{};
    final summary = snapshot['summary'] is Map
        ? Map<String, dynamic>.from(snapshot['summary'] as Map)
        : <String, dynamic>{};

    final weightHistory = (_dietProgress?['weightHistory'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    final currentWeight = weightHistory.isNotEmpty
        ? (weightHistory.first['weightKg'] as num?)?.toDouble()
        : (profile['weight'] as num?)?.toDouble();
    final previousWeight = weightHistory.length > 1
        ? (weightHistory[1]['weightKg'] as num?)?.toDouble()
        : null;
    final weightDelta =
        (currentWeight != null && previousWeight != null) ? currentWeight - previousWeight : null;

    final workoutSummary = _workoutProgress?['summary'] is Map
        ? Map<String, dynamic>.from(_workoutProgress!['summary'] as Map)
        : <String, dynamic>{};
    final history = (_workoutProgress?['history'] as List?) ?? const [];
    final completion = (workoutSummary['completionPercent'] as num?)?.toInt() ?? 0;
    final streak = _computeStreak(history);
    final steps = userId.isEmpty ? null : _latestStepsFor(userId);

    final caloriesIn = (summary['caloriesIn'] as num?)?.toDouble() ?? 0;
    final caloriesOut = (summary['caloriesOut'] as num?)?.toDouble() ?? 0;
    final waterMl = (summary['hydration'] as num?)?.toDouble() ?? 0;
    final goal = _fitnessGoalLabel(profile['fitness_goal']?.toString());
    final stats = _statsByClientId[userId] ?? _statsFromWorkoutProgress(_workoutProgress ?? {});

    final historyItems = <_HistoryItem>[
      ...history.take(8).whereType<Map>().map((h) {
        final status = h['status']?.toString() ?? '';
        final plan = h['exercisePlan'];
        final title = plan is Map ? (plan['title']?.toString() ?? 'Workout') : 'Workout';
        final when = h['completedAt'] ?? h['createdAt'] ?? h['submittedAt'];
        return _HistoryItem(
          title: title,
          subtitle: _formatDate(when?.toString()),
          status: status,
          icon: Icons.fitness_center_rounded,
        );
      }),
      ...((_dietProgress?['mealLogs'] as List?) ?? const [])
          .take(6)
          .whereType<Map>()
          .map((m) => _HistoryItem(
                title: m['mealType']?.toString().isNotEmpty == true
                    ? 'Meal · ${m['mealType']}'
                    : 'Meal logged',
                subtitle: '${_formatDate(m['date']?.toString())} · ${m['calories'] ?? 0} kcal',
                status: 'logged',
                icon: Icons.restaurant_rounded,
              )),
      ...((_dietProgress?['adherenceHistory'] as List?) ?? const [])
          .where((a) => a is Map && a['weightKg'] != null)
          .take(5)
          .whereType<Map>()
          .map((a) => _HistoryItem(
                title: 'Weight · ${a['weightKg']} kg',
                subtitle: _formatDate(a['date']?.toString()),
                status: 'weight',
                icon: Icons.monitor_weight_outlined,
              )),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: CoachDashboardTheme.cardDecoration(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProfileAvatar(
                    name: _clientNameOf(client),
                    photoUrl: _photoUrlOf(client),
                    radius: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _clientNameOf(client),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _statLabel('Complete', stats.completePct, stats.complete, _completeColor),
                  ),
                  Expanded(
                    child: _statLabel('Not Met', stats.notMetPct, stats.notMet, _notMetColor),
                  ),
                  Expanded(
                    child: _statLabel('Open', stats.openPct, stats.open, _openColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _segmentedBar(stats),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Overview', style: CoachDashboardTheme.sectionTitle(isDark)),
        const SizedBox(height: 12),
        _metricGrid(isDark, [
          _Metric(
            'Weight',
            currentWeight != null ? '${currentWeight.toStringAsFixed(1)} kg' : '—',
            Icons.monitor_weight_outlined,
            CoachDashboardTheme.primary,
            footer: weightDelta == null
                ? null
                : '${weightDelta >= 0 ? '+' : ''}${weightDelta.toStringAsFixed(1)} kg vs prior',
          ),
          _Metric('Goal', goal, Icons.flag_outlined, CoachDashboardTheme.accent),
          _Metric(
            'Workouts',
            '$completion%',
            Icons.fitness_center_rounded,
            CoachDashboardTheme.success,
            footer: '${workoutSummary['completed'] ?? 0} completed',
          ),
          _Metric(
            'Streak',
            '$streak day${streak == 1 ? '' : 's'}',
            Icons.local_fire_department_rounded,
            CoachDashboardTheme.warning,
          ),
          _Metric(
            'Steps',
            steps != null ? _formatNumber(steps) : '—',
            Icons.directions_walk_rounded,
            const Color(0xFF059669),
            footer: steps != null ? 'Latest tracked day' : 'No step data yet',
          ),
          _Metric(
            'Calories',
            '${caloriesIn.round()} in',
            Icons.local_fire_department_outlined,
            CoachDashboardTheme.pink,
            footer: '${caloriesOut.round()} out · last logs',
          ),
          _Metric(
            'Water',
            waterMl >= 1000 ? '${(waterMl / 1000).toStringAsFixed(1)} L' : '${waterMl.round()} ml',
            Icons.water_drop_outlined,
            CoachDashboardTheme.accent,
            footer: 'Recent intake',
          ),
        ]),
        const SizedBox(height: 20),
        Text('Progress history', style: CoachDashboardTheme.sectionTitle(isDark)),
        const SizedBox(height: 10),
        if (historyItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: CoachDashboardTheme.cardDecoration(isDark),
            child: Text(
              'No recent progress history for this client.',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
            ),
          )
        else
          Container(
            decoration: CoachDashboardTheme.cardDecoration(isDark),
            child: Column(
              children: [
                for (var i = 0; i < historyItems.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                  ListTile(
                    leading: Icon(historyItems[i].icon, color: CoachDashboardTheme.primary),
                    title: Text(
                      historyItems[i].title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(historyItems[i].subtitle, style: const TextStyle(fontSize: 12)),
                    trailing: _statusChip(historyItems[i].status),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('Send feedback'),
            onPressed: () {
              final assignmentId = client['_id']?.toString();
              if (assignmentId != null) _showFeedbackDialog(assignmentId);
            },
          ),
        ),
      ],
    );
  }

  Widget _metricGrid(bool isDark, List<_Metric> metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics
              .map((m) => SizedBox(width: width, child: _metricCard(isDark, m)))
              .toList(),
        );
      },
    );
  }

  Widget _metricCard(bool isDark, _Metric m) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(m.icon, size: 18, color: m.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  m.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            m.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          if (m.footer != null) ...[
            const SizedBox(height: 4),
            Text(
              m.footer!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'completed':
        color = CoachDashboardTheme.success;
        label = 'Done';
      case 'pending':
      case 'pending_review':
        color = CoachDashboardTheme.warning;
        label = 'Pending';
      case 'missed':
      case 'rejected':
        color = CoachDashboardTheme.danger;
        label = status == 'missed' ? 'Missed' : 'Rejected';
      case 'weight':
        color = CoachDashboardTheme.primary;
        label = 'Weight';
      default:
        color = CoachDashboardTheme.accent;
        label = 'Logged';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _formatDate(String? raw) {
    final dt = DateTime.tryParse(raw ?? '');
    if (dt == null) return '—';
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  String _formatNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  void _showFeedbackDialog(String assignmentId) {
    final controller = TextEditingController();
    var isSending = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Send feedback'),
              content: TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter your feedback here...',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          if (controller.text.trim().isEmpty) return;
                          setDialogState(() => isSending = true);
                          try {
                            await _apiService.sendFeedback({
                              'assignmentId': assignmentId,
                              'note': controller.text.trim(),
                            });
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Feedback sent'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSending = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ApiService.friendlyError(e)),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Metric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? footer;

  const _Metric(this.label, this.value, this.icon, this.color, {this.footer});
}

class _HistoryItem {
  final String title;
  final String subtitle;
  final String status;
  final IconData icon;

  const _HistoryItem({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.icon,
  });
}
