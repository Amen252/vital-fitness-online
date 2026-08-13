import 'package:flutter/material.dart';

/// Empty — the app has no loading UI.
class LottieLoading extends StatelessWidget {
  final double size;
  final Color? color;

  const LottieLoading({super.key, this.size = 72, this.color});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class LottieLoadingCenter extends StatelessWidget {
  final double size;
  const LottieLoadingCenter({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
