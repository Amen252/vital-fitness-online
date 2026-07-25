import 'package:flutter/material.dart';
import '../../screens/dashboard/widgets/coach_home/coach_dashboard_theme.dart';
import 'app_motion.dart';

class AnimatedNavItem {
  final IconData inactiveIcon;
  final IconData activeIcon;
  final String label;
  final int? badge;

  const AnimatedNavItem({
    required this.inactiveIcon,
    required this.activeIcon,
    required this.label,
    this.badge,
  });
}

/// Premium bottom navigation with animated selection indicator.
class AnimatedBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AnimatedNavItem> items;
  final bool isDark;
  final Color activeColor;
  final Color inactiveColor;

  const AnimatedBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.isDark,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CoachDashboardTheme.navBarBackground(isDark),
        border: Border(
          top: BorderSide(color: CoachDashboardTheme.shellBorder(isDark)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final selected = currentIndex == i;
              return Expanded(
                child: _NavCell(
                  selected: selected,
                  item: item,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  isDark: isDark,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  final bool selected;
  final AnimatedNavItem item;
  final Color activeColor;
  final Color inactiveColor;
  final bool isDark;
  final VoidCallback onTap;

  const _NavCell({
    required this.selected,
    required this.item,
    required this.activeColor,
    required this.inactiveColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: activeColor.withValues(alpha: 0.12),
        highlightColor: activeColor.withValues(alpha: 0.06),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppMotion.normal,
              curve: AppMotion.easeOut,
              padding: EdgeInsets.symmetric(horizontal: selected ? 14 : 0, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? activeColor.withValues(alpha: 0.16) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: selected
                    ? Border.all(color: activeColor.withValues(alpha: 0.35))
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: selected ? AppMotion.navIconScale : 1.0,
                    duration: AppMotion.normal,
                    curve: AppMotion.spring,
                    child: Icon(
                      selected ? item.activeIcon : item.inactiveIcon,
                      color: color,
                      size: 22,
                    ),
                  ),
                  if (item.badge != null && item.badge! > 0)
                    Positioned(
                      right: -10,
                      top: -6,
                      child: AnimatedOpacity(
                        opacity: 1,
                        duration: AppMotion.fast,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B),
                            shape: BoxShape.circle,
                            border: Border.all(color: CoachDashboardTheme.navBarBackground(isDark), width: 1.5),
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            item.badge! > 9 ? '9+' : '${item.badge}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              curve: AppMotion.easeOut,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}
