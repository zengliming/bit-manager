import 'package:flutter/material.dart';
import '../models/torrent.dart';

/// Holds the three color values for a torrent state visual treatment.
class StatusColors {
  final Color border;
  final Color background;
  final Color progress;

  const StatusColors({
    required this.border,
    required this.background,
    required this.progress,
  });
}

/// Returns the [StatusColors] for the given [TorrentState].
StatusColors statusColors(TorrentState state) {
  return switch (state) {
    TorrentState.downloading => const StatusColors(
      border: Color(0xFF4CAF50),
      background: Color(0x0D4CAF50),
      progress: Color(0xFF4CAF50),
    ),
    TorrentState.seeding => const StatusColors(
      border: Color(0xFF2196F3),
      background: Color(0x0D2196F3),
      progress: Color(0xFF2196F3),
    ),
    TorrentState.paused => const StatusColors(
      border: Color(0xFFFF9800),
      background: Color(0x0DFF9800),
      progress: Color(0xFFFF9800),
    ),
    TorrentState.error => const StatusColors(
      border: Color(0xFFE53935),
      background: Color(0x0DE53935),
      progress: Color(0xFFE53935),
    ),
    TorrentState.unknown => const StatusColors(
      border: Color(0xFFE53935),
      background: Color(0x0DE53935),
      progress: Color(0xFFE53935),
    ),
    _ => const StatusColors(
      border: Color(0xFF9E9E9E),
      background: Colors.transparent,
      progress: Color(0xFF9E9E9E),
    ),
  };
}
