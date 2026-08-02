import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dashboard/widgets/coach_home/coach_dashboard_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _supportEmail = 'support@vitalfitness.app';

  static const _faqs = [
    (
      'How do I update my profile?',
      'Open Settings from the bottom navigation, edit your details, and tap Save Profile Changes.',
    ),
    (
      'How do I contact my coach?',
      'Go to the Coaches tab, select your coach, and use Messages to start a conversation.',
    ),
    (
      'I forgot my password. What should I do?',
      'On the login screen, tap Forgot password, enter your email, and use the reset code we send you to set a new password.',
    ),
    (
      'How do I log workouts or meals?',
      'Use Quick Logs on the Home tab, or open Progress to track weight and daily activity.',
    ),
    (
      'Coach application status',
      'If you applied to become a coach, sign in and check your status. Approved coaches should sign out and sign back in.',
    ),
  ];

  void _copyEmail(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: _supportEmail));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Support email copied to clipboard'),
        backgroundColor: CoachDashboardTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: CoachDashboardTheme.homeBackground(isDark),
      appBar: CoachDashboardTheme.coachAppBar(
        context: context,
        title: 'Help & Support',
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: CoachDashboardTheme.cardDecoration(isDark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: CoachDashboardTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.support_agent_rounded, color: CoachDashboardTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Need help?', style: CoachDashboardTheme.sectionTitle(isDark)),
                          const SizedBox(height: 4),
                          Text(
                            'Browse FAQs below or reach our support team.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : CoachDashboardTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _supportEmail,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: CoachDashboardTheme.primary),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _copyEmail(context),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy support email'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text('Frequently Asked Questions', style: CoachDashboardTheme.sectionTitle(isDark)),
          ),
          ..._faqs.map(
            (faq) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: CoachDashboardTheme.cardDecoration(isDark),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  title: Text(
                    faq.$1,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        faq.$2,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: isDark ? Colors.white70 : CoachDashboardTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
