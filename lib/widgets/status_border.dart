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
      border: Color(0xFF34C759),
      background: Color(0x0D34C759),
      progress: Color(0xFF34C759),
    ),
    TorrentState.seeding => const StatusColors(
      border: Color(0xFF007AFF),
      background: Color(0x0D007AFF),
      progress: Color(0xFF007AFF),
    ),
    TorrentState.paused => const StatusColors(
      border: Color(0xFFFF9500),
      background: Color(0x0DFF9500),
      progress: Color(0xFFFF9500),
    ),
    TorrentState.error => const StatusColors(
      border: Color(0xFFFF3B30),
      background: Color(0x0DFF3B30),
      progress: Color(0xFFFF3B30),
    ),
    TorrentState.unknown => const StatusColors(
      border: Color(0xFFFF3B30),
      background: Color(0x0DFF3B30),
      progress: Color(0xFFFF3B30),
    ),
    _ => const StatusColors(
      border: Color(0xFF8E8E93),
      background: Colors.transparent,
      progress: Color(0xFF8E8E93),
    ),
  };
}
