import 'package:flutter/material.dart';

import '../screens/dashboard/widgets/coach_home/coach_dashboard_theme.dart';

/// User control to mark a workout complete — always opens the proof flow first.
class WorkoutMarkCompleteControl extends StatelessWidget {
  final String status;
  final bool isLoading;
  final VoidCallback? onMarkComplete;

  const WorkoutMarkCompleteControl({
    super.key,
    required this.status,
    this.isLoading = false,
    this.onMarkComplete,
  });

  bool get _isCompleted => status == 'completed';
  bool get _isInReview => status == 'pending_review';
  bool get _canMark => onMarkComplete != null && (status == 'pending' || status == 'missed');

  @override
  Widget build(BuildContext context) {
    if (_isCompleted || _isInReview) {
      return Icon(
        _isCompleted ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
        color: _isCompleted ? CoachDashboardTheme.success : CoachDashboardTheme.warning,
        size: 26,
      );
    }

    if (isLoading) {
      return const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2, color: CoachDashboardTheme.primary),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _canMark ? onMarkComplete : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            Icons.check_circle_outline_rounded,
            color: _canMark ? CoachDashboardTheme.primary : Colors.grey,
            size: 26,
          ),
        ),
      ),
    );
  }
}

/// Primary button to start the required proof submission flow.
class WorkoutCompleteButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final bool compact;

  const WorkoutCompleteButton({
    super.key,
    this.isLoading = false,
    this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return TextButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.check_circle_outline_rounded, size: 16),
        label: const Text('Mark complete'),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: CoachDashboardTheme.primaryButtonStyle(),
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.check_circle_outline_rounded, size: 18),
        label: Text(isLoading ? 'Submitting...' : 'Mark complete'),
      ),
    );
  }
}
