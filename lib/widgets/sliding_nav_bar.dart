import 'package:flutter/material.dart';

/// 自绘底部导航栏 — 单个胶囊指示器在选中项之间连续滑动
///
/// 取代 M3 NavigationBar 的逐项 fade 动画（视觉上像"跳帧"）。
/// 胶囊用 AnimatedAlign 在等宽槽位间位移，过渡丝滑。
class SlidingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavDestination> destinations;

  /// 动画时长与曲线
  static const Duration _duration = Duration(milliseconds: 260);
  static const Curve _curve = Curves.easeOutCubic;

  /// 胶囊宽度占单槽宽度的比例（M3 指示器约 60-80px，这里按比例）
  static const double _indicatorWidthFactor = 0.62;

  const SlidingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final indicatorColor = colorScheme.primary.withValues(alpha: 0.16);
    final selectedColor = colorScheme.primary;
    final unselectedColor = colorScheme.onSurfaceVariant;

    final n = destinations.length;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotWidth = constraints.maxWidth / n;
            final indicatorWidth = slotWidth * _indicatorWidthFactor;
            // 胶囊 left：选中槽左边缘 + 居中偏移，使胶囊中心精确对齐 tab 中心
            final indicatorLeft =
                slotWidth * selectedIndex + (slotWidth - indicatorWidth) / 2;
            return Stack(
              children: [
                // ── 滑动胶囊指示器（纵向居中）──
                Positioned(
                  left: indicatorLeft,
                  top: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: _duration,
                    curve: _curve,
                    width: indicatorWidth,
                    alignment: Alignment.center,
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: indicatorColor,
                        // 圆角 = 高度的一半，形成胶囊端（StadiumBorder 效果）
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                  ),
                ),
                // ── 各 tab 内容（撑满高度，居中）──
                Row(
                  children: List.generate(n, (i) {
                    final d = destinations[i];
                    final selected = i == selectedIndex;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onDestinationSelected(i),
                        child: _NavCell(
                          destination: d,
                          selected: selected,
                          selectedColor: selectedColor,
                          unselectedColor: unselectedColor,
                          duration: _duration,
                          curve: _curve,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  final NavDestination destination;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final Duration duration;
  final Curve curve;

  const _NavCell({
    required this.destination,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.duration,
    required this.curve,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;
    // 撑满格子高度后居中，避免内容被压到顶部
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: duration,
            transitionBuilder: (child, anim) {
              return FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              );
            },
            child: Icon(
            selected ? destination.selectedIcon : destination.icon,
            key: ValueKey(selected),
            size: selected ? 24 : 22,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: duration,
          curve: curve,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: color,
            fontFamilyFallback: const ['Inter'],
          ),
          child: Text(destination.label),
        ),
      ],
      ),
    );
  }
}

/// 导航项描述
class NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
