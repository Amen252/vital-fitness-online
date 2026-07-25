import 'package:flutter/material.dart';
import '../widgets/coach_home/coach_dashboard_theme.dart';
import '../../../models/user_model.dart';
import '../../../models/progress_model.dart';
import '../../../services/api_service.dart';
import '../../../widgets/scrollable_body.dart';
import '../../../widgets/animations/animations.dart';
import '../user_diet_plan_screen.dart';
import '../../../utils/share_helpers.dart';
import '../invite_friends_screen.dart';

class HomeTab extends StatefulWidget {
  final User user;
  final VoidCallback? onOpenDietPlan;
  final VoidCallback? onOpenMenu;

  const HomeTab({super.key, required this.user, this.onOpenDietPlan, this.onOpenMenu});

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  ProgressData? _progressData;
  Map<String, dynamic>? _coachingData;
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  final TextEditingController _waterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _fetchAll();
  }

  @override
  void dispose() {
    _animController.dispose();
    _waterController.dispose();
    super.dispose();
  }

  Future<void> refresh({bool showFeedback = false}) => _fetchAll(isRefresh: true, showFeedback: showFeedback);

  Future<void> _fetchAll({bool isRefresh = false, bool showFeedback = false}) async {
    final hadData = _progressData != null;

    if (!isRefresh && !hadData) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else if (isRefresh) {
      setState(() {
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        _apiService.getProgress().then<ProgressData?>((v) => v).catchError((_) => null),
        _apiService.getUserCoaching(),
      ]);

      if (!mounted) return;

      final progress = results[0] as ProgressData?;
      if (progress == null && !hadData) {
        throw Exception('Unable to load dashboard data');
      }

      setState(() {
        if (progress != null) _progressData = progress;
        _coachingData = results[1] as Map<String, dynamic>?;
        _isLoading = false;
      });

      if (!hadData && !isRefresh) {
        _animController.forward(from: 0);
      } else {
        _animController.value = 1.0;
      }

      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Dashboard updated'),
            backgroundColor: CoachDashboardTheme.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message = ApiService.friendlyError(e);
      if (hadData || _progressData != null) {
        setState(() {
          _isLoading = false;
        });
        if (isRefresh || showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: CoachDashboardTheme.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = message;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addWater(double ml) async {
    try {
      final ok = await _apiService.logWater(ml);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('💧 Logged ${ml.toInt()}ml water!'),
          backgroundColor: const Color(0xFF0288D1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        _fetchAll(isRefresh: true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiService.friendlyError(e)),
          backgroundColor: CoachDashboardTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submitWaterTotal() async {
    final raw = _waterController.text.trim();
    final ml = double.tryParse(raw);
    if (ml == null || ml <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a valid amount in ml'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    FocusScope.of(context).unfocus();
    _waterController.clear();
    await _addWater(ml);
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[now.weekday - 1]}, ${months[now.month]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final showInitialLoading = _isLoading && _progressData == null;
    final showInitialError = _errorMessage != null && _progressData == null;

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      body: AnimatedContentSwitcher(
        child: showInitialLoading
            ? const LottieLoadingCenter(key: ValueKey('loading'))
            : showInitialError
                ? _buildError(key: const ValueKey('error'))
                : FadeTransition(
                    key: const ValueKey('content'),
                    opacity: _fadeAnim,
                    child: PremiumRefreshIndicator(
                      onRefresh: () => _fetchAll(isRefresh: true),
                      child: CustomScrollView(
                      physics: dashboardScrollPhysics,
                      slivers: [
                        _buildHeroHeader(isDark),
                        SliverToBoxAdapter(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: MediaQuery.sizeOf(context).height - 140,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                const SizedBox(height: 20),
                                _buildSectionTitle('Today\'s Summary', Icons.insights_rounded, CoachDashboardTheme.primary).staggerIn(0),
                                const SizedBox(height: 12),
                                PremiumCard(index: 1, child: _buildMetricsGrid(isDark)),
                                const SizedBox(height: 12),
                                PremiumCard(index: 1, child: _buildShareRow(isDark)),
                                const SizedBox(height: 24),
                                _buildSectionTitle('Diet Plan', Icons.restaurant_menu_rounded, const Color(0xFF10B981)).staggerIn(2),
                                const SizedBox(height: 12),
                                PremiumCard(index: 2, child: _buildDietPlanCard(isDark)),
                                const SizedBox(height: 24),
                                _buildSectionTitle('Quick Logs', Icons.bolt_rounded, const Color(0xFFFFB74D)).staggerIn(3),
                                const SizedBox(height: 12),
                                PremiumCard(index: 4, child: _buildQuickLogs(isDark)),
                                const SizedBox(height: 24),
                                _buildSectionTitle('Your Insights', Icons.auto_awesome_rounded, Colors.purpleAccent).staggerIn(5),
                                const SizedBox(height: 12),
                                PremiumCard(index: 6, child: _buildAIInsightsCard(isDark)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildError({Key? key}) {
    return ScrollableCenter(
      key: key,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, size: 64, color: Color(0xFFFF6B6B)),
        const SizedBox(height: 16),
        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.grey)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _fetchAll,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: CoachDashboardTheme.primary, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    );
  }

  SliverToBoxAdapter _buildHeroHeader(bool isDark) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: CoachDashboardTheme.headerGradient,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (widget.onOpenMenu != null) ...[
              IconButton(
                tooltip: 'Menu',
                onPressed: widget.onOpenMenu,
                icon: Icon(Icons.menu_rounded, color: Colors.white.withValues(alpha: 0.95), size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: 6),
            ],
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
              ),
              child: Center(
                child: Text(
                  widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'U',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_greeting(), style: CoachDashboardTheme.greetingText(isDark)),
                Text(
                  widget.user.name,
                  style: CoachDashboardTheme.displayTitle(fontSize: 24),
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Text(_formattedDate(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _buildHeroStat('🔥', _progressData?.summary.caloriesOut ?? 0, 'kcal burned'),
            _buildHeroStatDivider(),
            _buildHeroStat('💧', _progressData?.summary.hydration ?? 0, 'ml water'),
            _buildHeroStatDivider(),
            _buildHeroStat('🥗', _progressData?.summary.caloriesIn ?? 0, 'kcal eaten'),
          ]),
        ]),
      ),
    );
  }

  Widget _buildHeroStat(String emoji, num value, String label) {
    return Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 4),
      AnimatedStatValue(
        value: value,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 11)),
    ]);
  }

  Widget _buildHeroStatDivider() => Container(height: 36, width: 1, color: Colors.white.withOpacity(0.2));

  Widget _buildShareRow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Share your wins', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Create a branded public card or invite a friend.',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => shareVitalCard(context, type: 'progress'),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Share progress'),
              ),
              OutlinedButton.icon(
                onPressed: () => shareVitalCard(context, type: 'weekly'),
                icon: const Icon(Icons.calendar_view_week_rounded, size: 18),
                label: const Text('Weekly win'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InviteFriendsScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CoachDashboardTheme.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Invite'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 8),
      Text(title, style: CoachDashboardTheme.sectionTitle(true)),
    ]);
  }

  Widget _buildMetricsGrid(bool isDark) {
    final metrics = [
      _MetricData('Calories Out', '${_progressData?.summary.caloriesOut.toInt() ?? 0} kcal', Icons.local_fire_department_rounded, [const Color(0xFFFFB74D), const Color(0xFFF57C00)]),
      _MetricData('Calories In', '${_progressData?.summary.caloriesIn.toInt() ?? 0} kcal', Icons.restaurant_rounded, [const Color(0xFFEF5350), const Color(0xFFC62828)]),
      _MetricData('Hydration', '${_progressData?.summary.hydration.toInt() ?? 0} ml', Icons.water_drop_rounded, [const Color(0xFF29B6F6), const Color(0xFF0277BD)]),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemCount: metrics.length,
      itemBuilder: (_, i) => _buildMetricCard(metrics[i]),
    );
  }

  Widget _buildMetricCard(_MetricData m) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: m.colors),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: m.colors.last.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(m.icon, color: Colors.white, size: 24),
        const Spacer(),
        Text(m.label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(m.value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }


  Widget _buildDietPlanCard(bool isDark) {
    final coachName = _coachingData?['coach']?['name'] as String? ?? 'Your Coach';

    return ScalePress(
      onTap: () {
        if (widget.onOpenDietPlan != null) {
          widget.onOpenDietPlan!();
        } else {
          AppNavigator.push(context, const UserDietPlanScreen());
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF181B24) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.07), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF06B6D4)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('My Diet Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              'View meals, calories, and nutrition from $coachName',
              style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.4),
            ),
          ])),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
        ]),
      ),
    );
  }

  Widget _buildQuickLogs(bool isDark) {
    return _buildWaterInputField(isDark);
  }

  Widget _buildWaterInputField(bool isDark) {
    const color = Color(0xFF29B6F6);
    return TextField(
      controller: _waterController,
      keyboardType: TextInputType.number,
      onSubmitted: (_) => _submitWaterTotal(),
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.water_drop_rounded, color: color, size: 20),
        labelText: 'Total water consumed today (ml)',
        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
        filled: true,
        fillColor: color.withValues(alpha: 0.08),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilledButton.icon(
            onPressed: _submitWaterTotal,
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Send'),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: color, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
      ),
    );
  }

  Widget _buildAIInsightsCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181B24) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.07), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.purple.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.purpleAccent, size: 22),
          ),
          const SizedBox(width: 10),
          const Text('Your Insights', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        const SizedBox(height: 14),
        if (_progressData?.reports.isEmpty ?? true)
          Text(
            'Log your meals, water, and workouts to unlock personalized insights.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
          )
        else
          ..._progressData!.reports.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('•  ', style: TextStyle(color: CoachDashboardTheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
              Expanded(child: Text(r, style: const TextStyle(fontSize: 13, height: 1.5))),
            ]),
          )),
      ]),
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> colors;
  _MetricData(this.label, this.value, this.icon, this.colors);
}
