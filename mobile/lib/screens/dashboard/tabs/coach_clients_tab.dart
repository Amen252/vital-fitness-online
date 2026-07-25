import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/scrollable_body.dart';
import '../../../widgets/tab_refresh.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';
import '../widgets/coach_requests_panel.dart';
import 'coach_client_detail_screen.dart';

class CoachClientsTab extends StatefulWidget {
  final VoidCallback? onPendingCountChanged;
  final VoidCallback? onClientsChanged;

  const CoachClientsTab({
    super.key,
    this.onPendingCountChanged,
    this.onClientsChanged,
  });

  @override
  CoachClientsTabState createState() => CoachClientsTabState();
}

class CoachClientsTabState extends State<CoachClientsTab> with TabRefreshMixin {
  final ApiService _apiService = ApiService();
  int _selectedView = 0;
  int _pendingRequestCount = 0;
  List<dynamic> _clients = [];
  List<dynamic> _filteredClients = [];
  String _statusFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchClients();
    _searchController.addListener(_filterClients);
  }

  void openRequestsTab() {
    if (!mounted) return;
    setState(() => _selectedView = 1);
  }

  int get pendingRequestCount => _pendingRequestCount;

  Future<void> refresh() => _fetchClients(isRefresh: true);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchClients({bool isRefresh = false}) async {
    beginTabLoad(isRefresh: isRefresh);
    try {
      final clients = await _apiService.getCoachClients();
      final requests = await _apiService.getCoachRequests();
      if (mounted) {
        finishTabLoad(() {
          final pendingCount = List<dynamic>.from(requests).length;
          _clients = List<dynamic>.from(clients);
          _filteredClients = List<dynamic>.from(clients);
          _pendingRequestCount = pendingCount;
          if (pendingCount > 0 && _selectedView == 0) {
            _selectedView = 1;
          }
        });
        widget.onPendingCountChanged?.call();
      }
    } catch (e) {
      finishTabError(e, isRefresh: isRefresh);
    }
  }

  void _filterClients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredClients = _clients.where((c) {
        final userMap = c['user'] is Map ? Map<dynamic, dynamic>.from(c['user'] as Map) : null;
        final name = ApiService.displayName(userMap).toLowerCase();
        final identity = ApiService.displayIdentity(userMap).toLowerCase();
        final needsAction = c['snapshot']?['analysis']?['isActionRequired'] == true;

        final matchesSearch = query.isEmpty || name.contains(query) || identity.contains(query);
        final matchesFilter = _statusFilter == 'all'
            || (_statusFilter == 'action' && needsAction)
            || (_statusFilter == 'track' && !needsAction);

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _setFilter(String filter) {
    setState(() => _statusFilter = filter);
    _filterClients();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CoachPage(
      title: 'My Clients',
      actions: [
        IconButton(
          icon: tabRefreshIcon(color: Colors.white),
          onPressed: (showInitialLoading || tabIsRefreshing) ? null : refresh,
        ),
      ],
      body: showInitialLoading
          ? const ScrollableCenter(child: CircularProgressIndicator(color: CoachDashboardTheme.primary))
          : showInitialError
              ? ScrollableCenter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      Text('Error: $tabLoadError', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: () => _fetchClients(), child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _buildViewSwitcher(isDark),
                    ),
                    if (_selectedView == 0) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: TextField(
                          controller: _searchController,
                          decoration: CoachDashboardTheme.searchDecoration(isDark: isDark, hint: 'Search clients...'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _filterChip('All', 'all', isDark),
                              const SizedBox(width: 8),
                              _filterChip('Needs Action', 'action', isDark),
                              const SizedBox(width: 8),
                              _filterChip('On Track', 'track', isDark),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: _filteredClients.isEmpty
                            ? CoachDashboardTheme.emptyState(
                                icon: Icons.group_off_rounded,
                                message: 'No clients found.',
                                isDark: isDark,
                              )
                            : ListView.builder(
                                physics: dashboardScrollPhysics,
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                                itemCount: _filteredClients.length,
                                itemBuilder: (context, index) {
                                  final client = _filteredClients[index];
                                  return _ClientCard(client: client, isDark: isDark, onRefresh: () => _fetchClients(isRefresh: true));
                                },
                              ),
                      ),
                    ] else
                      Expanded(
                        child: CoachRequestsPanel(
                          onRequestHandled: () {
                            _fetchClients(isRefresh: true);
                            widget.onPendingCountChanged?.call();
                            widget.onClientsChanged?.call();
                          },
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildViewSwitcher(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181B24) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _viewButton(isDark: isDark, label: 'My Clients', count: _clients.length, selected: _selectedView == 0, onTap: () => setState(() => _selectedView = 0)),
          _viewButton(isDark: isDark, label: 'Requests', count: _pendingRequestCount, selected: _selectedView == 1, onTap: () => setState(() => _selectedView = 1)),
        ],
      ),
    );
  }

  Widget _viewButton({
    required bool isDark,
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? (isDark ? CoachDashboardTheme.primary.withValues(alpha: 0.25) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? CoachDashboardTheme.primary : (isDark ? Colors.white54 : CoachDashboardTheme.textSecondary),
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? CoachDashboardTheme.primary : (isDark ? Colors.white38 : Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value, bool isDark) {
    return CoachDashboardTheme.filterChip(
      label: label,
      selected: _statusFilter == value,
      isDark: isDark,
      onTap: () => _setFilter(value),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final Map<String, dynamic> client;
  final bool isDark;
  final VoidCallback onRefresh;

  const _ClientCard({required this.client, required this.isDark, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final userMap = client['user'] is Map ? Map<dynamic, dynamic>.from(client['user'] as Map) : null;
    final name = ApiService.displayName(userMap, fallback: 'Client');
    final identity = ApiService.displayIdentity(userMap);
    final snapshot = client['snapshot'] ?? {};
    final analysis = snapshot['analysis'] ?? {};

    final rawScore = analysis['healthScore'];
    final healthScore = rawScore is num ? rawScore.round().toString() : null;
    final isActionRequired = analysis['isActionRequired'] == true;
    final isNewClient = analysis['isNewClient'] == true || healthScore == null;

    final Color badgeColor;
    final String badgeLabel;
    if (isActionRequired) {
      badgeColor = CoachDashboardTheme.danger;
      badgeLabel = healthScore != null ? 'Score: $healthScore' : 'Needs review';
    } else if (isNewClient) {
      badgeColor = CoachDashboardTheme.primary;
      badgeLabel = 'New';
    } else {
      badgeColor = CoachDashboardTheme.success;
      badgeLabel = 'Score: $healthScore';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CoachClientDetailScreen(clientData: client),
              ),
            ).then((_) => onRefresh());
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CoachDashboardTheme.avatarBox(
                  initial: name.isNotEmpty ? name[0].toUpperCase() : 'C',
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isDark ? Colors.white : CoachDashboardTheme.textPrimary,
                        ),
                      ),
                      if (identity.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          identity,
                          style: TextStyle(
                            color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (isActionRequired) ...[
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: CoachDashboardTheme.warning, size: 14),
                          SizedBox(width: 4),
                          Text('Needs action', style: TextStyle(color: CoachDashboardTheme.warning, fontSize: 10)),
                        ],
                      ),
                    ] else if (isNewClient) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Getting started',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
