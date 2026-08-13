import 'package:flutter/material.dart';
import '../../dashboard/widgets/coach_home/coach_dashboard_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/api_service.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _stats;
  List<dynamic> _coaches = [];

  static const _chartColors = [
    CoachDashboardTheme.primary,
    CoachDashboardTheme.accent,
    CoachDashboardTheme.success,
    CoachDashboardTheme.warning,
    CoachDashboardTheme.pink,
    CoachDashboardTheme.danger,
  ];

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _apiService.getAdminStatistics(),
        _apiService.getAdminTrainers(),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          _coaches = results[1] as List<dynamic>;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      appBar: CoachDashboardTheme.coachAppBar(
        context: context,
        title: 'Reports & Analytics',
        centerTitle: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchStats),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: CoachDashboardTheme.danger)),
            TextButton(onPressed: _fetchStats, child: const Text('Retry')),
          ],
        ),
      );
    }

    final userGrowth = _stats?['userGrowth'] as List<dynamic>? ?? [];
    final activityByType = _stats?['activityByType'] as List<dynamic>? ?? [];
    final mealsByDay = _stats?['mealsByDay'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('User Signups (30 days)', Icons.trending_up_rounded, CoachDashboardTheme.primary),
        const SizedBox(height: 12),
        _chartCard(
          isDark,
          height: 250,
          child: userGrowth.isEmpty
              ? const Center(child: Text('No signup data yet'))
              : _buildGrowthChart(isDark, userGrowth),
        ),
        const SizedBox(height: 28),
        _sectionHeader('Activity by Type', Icons.fitness_center_rounded, CoachDashboardTheme.accent),
        const SizedBox(height: 12),
        _chartCard(
          isDark,
          height: 250,
          child: activityByType.isEmpty
              ? const Center(child: Text('No activity data yet'))
              : _buildActivityPie(isDark, activityByType),
        ),
        const SizedBox(height: 28),
        _sectionHeader('Meal Calories (30 days)', Icons.restaurant_rounded, CoachDashboardTheme.success),
        const SizedBox(height: 12),
        _chartCard(
          isDark,
          height: 250,
          child: mealsByDay.isEmpty
              ? const Center(child: Text('No meal data yet'))
              : _buildMealsChart(isDark, mealsByDay),
        ),
        const SizedBox(height: 28),
        _sectionHeader('Coach Performance', Icons.school_rounded, CoachDashboardTheme.warning),
        const SizedBox(height: 12),
        _buildCoachList(isDark),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _chartCard(bool isDark, {required double height, required Widget child}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: CoachDashboardTheme.cardDecoration(isDark),
      child: child,
    );
  }

  Widget _buildGrowthChart(bool isDark, List<dynamic> data) {
    final values = data.map((d) => (d['count'] as num).toDouble()).toList();
    final maxY = values.isEmpty ? 5.0 : values.reduce((a, b) => a > b ? a : b) + 1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                final parts = (data[i]['_id'] as String).split('-');
                return Text(parts.length == 3 ? '${parts[2]}/${parts[1]}' : '', style: const TextStyle(fontSize: 9));
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(values.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: values[i],
                color: CoachDashboardTheme.primary,
                width: 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildActivityPie(bool isDark, List<dynamic> data) {
    final total = data.fold<double>(0, (sum, d) => sum + (d['total'] as num).toDouble());
    if (total == 0) return const Center(child: Text('No data'));

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 36,
        sections: List.generate(data.length, (i) {
          final item = data[i];
          final value = (item['total'] as num).toDouble();
          final label = item['_id'] as String? ?? 'Other';
          return PieChartSectionData(
            value: value,
            title: label.length > 8 ? '${label.substring(0, 8)}…' : label,
            color: _chartColors[i % _chartColors.length],
            radius: 52,
            titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
          );
        }),
      ),
    );
  }

  Widget _buildMealsChart(bool isDark, List<dynamic> data) {
    final spots = <FlSpot>[];
    double maxY = 0;
    for (int i = 0; i < data.length; i++) {
      final y = (data[i]['totalCalories'] as num).toDouble();
      if (y > maxY) maxY = y;
      spots.add(FlSpot(i.toDouble(), y));
    }
    if (maxY == 0) maxY = 100;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.1,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                final parts = (data[i]['_id'] as String).split('-');
                return Text(parts.length == 3 ? '${parts[2]}/${parts[1]}' : '', style: const TextStyle(fontSize: 9));
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: CoachDashboardTheme.success,
            barWidth: 3,
            belowBarData: BarAreaData(show: true, color: CoachDashboardTheme.success.withValues(alpha: 0.15)),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachList(bool isDark) {
    final sorted = List<dynamic>.from(_coaches)
      ..sort((a, b) => _clientCount(b).compareTo(_clientCount(a)));

    if (sorted.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: CoachDashboardTheme.cardDecoration(isDark),
        child: const Center(child: Text('No coaches found')),
      );
    }

    return Column(
      children: sorted.take(8).map((c) {
        final name = ApiService.displayName(
          c is Map ? Map<dynamic, dynamic>.from(c) : null,
          fallback: 'Coach',
        );
        final clients = _clientCount(c);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: CoachDashboardTheme.cardDecoration(isDark),
          child: ListTile(
            leading: CoachDashboardTheme.avatarBox(initial: name.isNotEmpty ? name[0].toUpperCase() : 'C', size: 40),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('$clients active clients'),
            trailing: Text(
              '$clients',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: CoachDashboardTheme.primary),
            ),
          ),
        );
      }).toList(),
    );
  }

  int _clientCount(dynamic coach) => (coach['activeClients'] as num? ?? 0).toInt();
}
