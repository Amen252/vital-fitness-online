import 'package:flutter/material.dart';
import '../../dashboard/widgets/coach_home/coach_dashboard_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/user_model.dart';
import '../../../services/api_service.dart';
import '../../../utils/async_load.dart';
import '../../../widgets/scrollable_body.dart';
import '../screens/admin_reports_screen.dart';

class AdminHomeTab extends StatefulWidget {
  final User adminUser;

  const AdminHomeTab({super.key, required this.adminUser});

  @override
  AdminHomeTabState createState() => AdminHomeTabState();
}

class AdminHomeTabState extends State<AdminHomeTab> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic>? _coaches;
  Map<String, dynamic>? _dashboardStats;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final showFullLoader = _dashboardStats == null;
    setState(() {
      if (showFullLoader) _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await waitIsolatedTimed<Object?>([
        _apiService.getAdminDashboardStats(),
        _apiService.getAdminTrainers(),
      ], fallback: null, timeout: const Duration(seconds: 25));
      if (mounted) {
        final stats = results[0] is Map
            ? Map<String, dynamic>.from(results[0] as Map)
            : null;
        final coaches = results[1] is List
            ? List<dynamic>.from(results[1] as List)
            : <dynamic>[];
        setState(() {
          if (stats != null) _dashboardStats = stats;
          _coaches = coaches;
          if (stats == null && coaches.isEmpty) {
            _errorMessage = 'Unable to load data';
          } else {
            _errorMessage = null;
          }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const ScrollableCenter(child: CircularProgressIndicator(color: CoachDashboardTheme.primary));
    }
    if (_errorMessage != null) {
      return ScrollableCenter(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error loading stats', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: refresh, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_dashboardStats == null) {
      return const ScrollableCenter(child: Text('No data available'));
    }

    return SingleChildScrollView(
      physics: dashboardScrollPhysics,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeBanner(theme, isDark),
          const SizedBox(height: 24),
          _buildSummaryCards(isDark),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: Text(
                  'User Growth (Last 30 Days)',
                  style: CoachDashboardTheme.sectionTitle(isDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminReportsScreen()),
                ),
                child: const Text('Full Report'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildUserGrowthChart(isDark),
          const SizedBox(height: 32),
          Text('Top Coaches', style: CoachDashboardTheme.sectionTitle(isDark)),
          const SizedBox(height: 16),
          _buildTopCoaches(isDark),
          const SizedBox(height: 32),
          Text('Recent Signups', style: CoachDashboardTheme.sectionTitle(isDark)),
          const SizedBox(height: 16),
          _buildRecentSignups(isDark),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: CoachDashboardTheme.headerGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CoachDashboardTheme.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome back, ${widget.adminUser.name.split(' ').first}!",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Here's what's happening with VitalFitness today.",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
          const Icon(Icons.admin_panel_settings, size: 48, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    final users = _dashboardStats?['totalUsers'] ?? 0;
    final coaches = _dashboardStats?['totalCoaches'] ?? 0;
    final activeMembers = _dashboardStats?['totalAssignments'] ?? 0;
    final activities = _dashboardStats?['totalActivities'] ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildStatCard('Total Coaches', '$coaches', Icons.sports, CoachDashboardTheme.warning, cardWidth, isDark),
            _buildStatCard('Total Users', '$users', Icons.people, CoachDashboardTheme.primary, cardWidth, isDark),
            _buildStatCard('Active Clients', '$activeMembers', Icons.check_circle, CoachDashboardTheme.success, cardWidth, isDark),
            _buildStatCard('Activities Logged', '$activities', Icons.fitness_center, CoachDashboardTheme.accent, cardWidth, isDark),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, double width, bool isDark) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(value, style: CoachDashboardTheme.metricValue(color)),
          const SizedBox(height: 4),
          Text(title, style: CoachDashboardTheme.metricLabel(isDark)),
        ],
      ),
    );
  }

  Widget _buildUserGrowthChart(bool isDark) {
    final growthData = _dashboardStats?['userGrowth'] as List<dynamic>?;
    if (growthData == null || growthData.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: CoachDashboardTheme.cardDecoration(isDark),
        child: const Text('Not enough data to display chart.'),
      );
    }

    final spots = <FlSpot>[];
    double maxCount = 0;
    for (int i = 0; i < growthData.length; i++) {
      final count = (growthData[i]['count'] as num).toDouble();
      if (count > maxCount) maxCount = count;
      spots.add(FlSpot(i.toDouble(), count));
    }
    if (maxCount == 0) maxCount = 5;

    return Container(
      height: 250,
      padding: const EdgeInsets.only(right: 16, top: 24, bottom: 12),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark ? Colors.white10 : Colors.black12,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < growthData.length) {
                    final parts = (growthData[idx]['_id'] as String).split('-');
                    if (parts.length == 3) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${parts[2]}/${parts[1]}',
                          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 10),
                        ),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 10),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (growthData.length - 1).toDouble(),
          minY: 0,
          maxY: maxCount + (maxCount * 0.2),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: CoachDashboardTheme.primary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: CoachDashboardTheme.primary.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCoaches(bool isDark) {
    final coaches = List<dynamic>.from(_coaches ?? [])
      ..sort((a, b) => _clientCount(b).compareTo(_clientCount(a)));

    if (coaches.isEmpty) {
      return Text('No coaches yet.', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey));
    }

    return Container(
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: coaches.take(5).length,
        separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
        itemBuilder: (context, index) {
          final coach = coaches[index];
          final name = ApiService.displayName(
            coach is Map ? Map<dynamic, dynamic>.from(coach) : null,
            fallback: 'Unknown',
          );
          final clients = _clientCount(coach);
          final suspended = coach['status'] == 'suspended';
          return ListTile(
            leading: CoachDashboardTheme.avatarBox(initial: name.isNotEmpty ? name[0].toUpperCase() : 'C', size: 40),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('$clients active clients'),
            trailing: suspended
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: CoachDashboardTheme.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Suspended', style: TextStyle(color: CoachDashboardTheme.danger, fontSize: 11)),
                  )
                : null,
          );
        },
      ),
    );
  }

  int _clientCount(dynamic coach) => (coach['activeClients'] as num? ?? 0).toInt();

  Widget _buildRecentSignups(bool isDark) {
    final signups = _dashboardStats?['recentSignups'] as List<dynamic>?;
    if (signups == null || signups.isEmpty) {
      return const Text('No recent signups.');
    }

    return Container(
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: signups.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
        itemBuilder: (context, index) {
          final user = signups[index];
          final userMap = user is Map ? Map<dynamic, dynamic>.from(user) : null;
          final name = ApiService.displayName(userMap, fallback: 'Unknown User');
          final identity = ApiService.displayIdentity(userMap);
          final date = DateTime.tryParse(user['createdAt'] as String? ?? '');
          final dateFormatted = date != null ? '${date.day}/${date.month}/${date.year}' : '';
          return ListTile(
            leading: CoachDashboardTheme.avatarBox(
              initial: name.isNotEmpty ? name[0].toUpperCase() : '?',
              size: 40,
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(identity.isEmpty ? 'No username' : identity),
            trailing: Text(dateFormatted, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
          );
        },
      ),
    );
  }
}
