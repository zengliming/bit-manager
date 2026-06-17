import 'package:flutter/material.dart';

/// 悬浮底部导航栏
///
/// 不贴边、圆角胶囊漂浮在页面上方，半透明背景 + 阴影。
/// 选中：图标换实心 + primary 色，文字 primary 色加粗；
/// 未选：outline 图标 + 灰色文字。无胶囊背景、无滑动动画。
class FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<FloatingNavDestination> destinations;

  static const double _height = 64;

  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedColor = colorScheme.primary;
    final unselectedColor = colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        height: _height,
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: List.generate(destinations.length, (i) {
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
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  final FloatingNavDestination destination;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;

  const _NavCell({
    required this.destination,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          selected ? destination.selectedIcon : destination.icon,
          size: selected ? 24 : 22,
          color: color,
        ),
        const SizedBox(height: 4),
        Text(
          destination.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: color,
          ),
        ),
      ],
    );
  }
}

class FloatingNavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const FloatingNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
