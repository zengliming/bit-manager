import 'package:flutter/material.dart';
import '../models/torrent.dart';

/// A simple record holding the three color values for a torrent state.
record StatusColors({
  required Color border,
  required Color background,
  required Color progress,
});

/// Returns the [StatusColors] for the given [TorrentState].
StatusColors statusColors(TorrentState state) {
  return switch (state) {
    // downloading → green border, 5% opacity background, solid progress
    TorrentState.downloading => const StatusColors(
      border: Color(0xFF4CAF50),
      background: Color(0x0D4CAF50), // 5% opacity
      progress: Color(0xFF4CAF50),
    ),
    // seeding → blue
    TorrentState.seeding => const StatusColors(
      border: Color(0xFF2196F3),
      background: Color(0x0D2196F3),
      progress: Color(0xFF2196F3),
    ),
    // paused → orange
    TorrentState.paused => const StatusColors(
      border: Color(0xFFFF9800),
      background: Color(0x0DFF9800),
      progress: Color(0xFFFF9800),
    ),
    // error / unknown → red
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
    // All other states → gray, transparent background
    _ => const StatusColors(
      border: Color(0xFF9E9E9E),
      background: Colors.transparent,
      progress: Color(0xFF9E9E9E),
    ),
  };
}
