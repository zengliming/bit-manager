import 'package:flutter/material.dart';

/// 可折叠侧边导航栏
///
/// 收起时仅一条窄条（汉堡按钮 + 选中项图标），展开时显示图标 + 文字。
/// 点顶部汉堡按钮切换展开/收起。选中某项后可自动收起（可选）。
class CollapsibleSideNav extends StatelessWidget {
  final int selectedIndex;
  final bool expanded;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onToggleExpand;
  final List<NavDestinationItem> destinations;

  static const double _collapsedWidth = 60;
  static const double _expandedWidth = 200;
  static const Duration _duration = Duration(milliseconds: 220);
  static const Curve _curve = Curves.easeOutCubic;

  const CollapsibleSideNav({
    super.key,
    required this.selectedIndex,
    required this.expanded,
    required this.onDestinationSelected,
    required this.onToggleExpand,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedColor = colorScheme.primary;
    final unselectedColor = colorScheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: _duration,
      curve: _curve,
      width: expanded ? _expandedWidth : _collapsedWidth,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部汉堡按钮（切换展开/收起）
          SizedBox(
            height: 56,
            child: IconButton(
              icon: Icon(
                expanded ? Icons.menu_open : Icons.menu,
                color: colorScheme.onSurface,
              ),
              onPressed: onToggleExpand,
              tooltip: expanded ? '收起' : '展开',
            ),
          ),
          const SizedBox(height: 4),
          // 导航项
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: List.generate(destinations.length, (i) {
                final d = destinations[i];
                final selected = i == selectedIndex;
                return _NavItem(
                  destination: d,
                  selected: selected,
                  expanded: expanded,
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor,
                  duration: _duration,
                  curve: _curve,
                  onTap: () => onDestinationSelected(i),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final NavDestinationItem destination;
  final bool selected;
  final bool expanded;
  final Color selectedColor;
  final Color unselectedColor;
  final Duration duration;
  final Curve curve;
  final VoidCallback onTap;

  const _NavItem({
    required this.destination,
    required this.selected,
    required this.expanded,
    required this.selectedColor,
    required this.unselectedColor,
    required this.duration,
    required this.curve,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;
    final indicatorColor = selectedColor.withValues(alpha: 0.14);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? indicatorColor : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: duration,
            curve: curve,
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 12 : 0,
              vertical: 10,
            ),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 24,
                  color: color,
                ),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: duration,
                      curve: curve,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: color,
                      ),
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NavDestinationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const NavDestinationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
