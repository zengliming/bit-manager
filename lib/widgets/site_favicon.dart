import 'package:flutter/material.dart';

/// 站点图标组件
/// 从 assets/sites/icons/ 加载图标，失败时显示首字母占位符
class SiteFavicon extends StatelessWidget {
  final String? iconAsset;
  final String siteName;
  final double size;
  final double radius;

  const SiteFavicon({
    super.key,
    this.iconAsset,
    required this.siteName,
    this.size = 40,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (iconAsset != null && iconAsset!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            iconAsset!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholder(context),
          ),
        ),
      );
    }
    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    final letter = siteName.isNotEmpty ? siteName[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
