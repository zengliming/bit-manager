import 'package:flutter/material.dart';

/// Hero speed display card for HomeScreen.
/// Shows download/upload speeds with large numbers and icons.
class SpeedHeroCard extends StatelessWidget {
  final int downloadSpeed; // bytes/s
  final int uploadSpeed;   // bytes/s

  const SpeedHeroCard({
    super.key,
    required this.downloadSpeed,
    required this.uploadSpeed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.12),
            theme.colorScheme.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(child: _SpeedColumn(
            icon: Icons.arrow_downward,
            iconColor: const Color(0xFF4CAF50),
            label: '下载',
            speed: downloadSpeed,
            textColor: const Color(0xFF2E7D32),
          )),
          Container(
            width: 1,
            height: 60,
            color: Colors.grey.withValues(alpha: 0.2),
          ),
          Expanded(child: _SpeedColumn(
            icon: Icons.arrow_upward,
            iconColor: const Color(0xFF2196F3),
            label: '上传',
            speed: uploadSpeed,
            textColor: const Color(0xFF1565C0),
          )),
        ],
      ),
    );
  }
}

class _SpeedColumn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int speed;
  final Color textColor;

  const _SpeedColumn({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.speed,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: _formatSpeed(speed),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatSpeed(int bytes) {
    if (bytes <= 0) return '0 KB/s';
    if (bytes < 1024) return '${bytes}B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)}KB/s';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB/s';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)}GB/s';
  }
}
