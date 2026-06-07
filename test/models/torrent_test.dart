import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/models/torrent.dart';
import 'package:flutter_test/flutter_test.dart';

Torrent _torrent({
  TorrentState state = TorrentState.downloading,
  int downloadSpeed = 0,
  int uploadSpeed = 0,
  ClientType clientType = ClientType.transmission,
  List<String> trackerStatuses = const ['Success'],
}) {
  return Torrent(
    id: 'torrent-1',
    hash: 'hash-1',
    name: 'Torrent 1',
    clientId: 'client-1',
    clientType: clientType,
    state: state,
    downloadSpeed: downloadSpeed,
    uploadSpeed: uploadSpeed,
    trackerStatuses: trackerStatuses,
  );
}

void main() {
  group('Torrent tracker classification', () {
    test('does not mark tracker as error when any tracker status contains Success', () {
      final torrent = _torrent(
        trackerStatuses: const ['Timeout', 'Success', 'Connection refused'],
      );

      expect(torrent.hasSuccessfulTracker, isTrue);
      expect(torrent.hasTrackerError, isFalse);
      expect(torrent.isError, isFalse);
    });

    test('uses qBittorrent numeric tracker status 2 as success', () {
      final torrent = _torrent(
        clientType: ClientType.qBittorrent,
        trackerStatuses: const ['Timeout', '2'],
      );

      expect(torrent.hasSuccessfulTracker, isTrue);
      expect(torrent.hasTrackerError, isFalse);
      expect(torrent.isError, isFalse);
    });

    test('does not use Success text for qBittorrent tracker success', () {
      final torrent = _torrent(
        clientType: ClientType.qBittorrent,
        trackerStatuses: const ['Success'],
      );

      expect(torrent.hasSuccessfulTracker, isFalse);
      expect(torrent.hasTrackerError, isTrue);
      expect(torrent.isError, isTrue);
    });

    test('uses Success text for Transmission tracker success', () {
      final torrent = _torrent(
        clientType: ClientType.transmission,
        trackerStatuses: const ['Success'],
      );

      expect(torrent.hasSuccessfulTracker, isTrue);
      expect(torrent.hasTrackerError, isFalse);
      expect(torrent.isError, isFalse);
    });

    test('marks tracker as error when no tracker status contains Success', () {
      final torrent = _torrent(
        trackerStatuses: const ['Timeout', 'Not contacted yet'],
      );

      expect(torrent.hasSuccessfulTracker, isFalse);
      expect(torrent.hasTrackerError, isTrue);
      expect(torrent.isError, isTrue);
    });

    test('marks empty tracker status list as tracker error', () {
      final torrent = _torrent(trackerStatuses: const []);

      expect(torrent.hasSuccessfulTracker, isFalse);
      expect(torrent.hasTrackerError, isTrue);
      expect(torrent.isError, isTrue);
    });

    test('marks error and unknown states as errors even with successful tracker', () {
      final errorTorrent = _torrent(state: TorrentState.error);
      final unknownTorrent = _torrent(state: TorrentState.unknown);

      expect(errorTorrent.isError, isTrue);
      expect(unknownTorrent.isError, isTrue);
    });
  });

  group('Torrent activity classification', () {
    test('uses upload speed to classify active uploads', () {
      final active = _torrent(uploadSpeed: 1);
      final inactive = _torrent(uploadSpeed: 0);

      expect(active.isActivelyUploading, isTrue);
      expect(inactive.isActivelyUploading, isFalse);
    });

    test('uses download speed to classify active downloads', () {
      final active = _torrent(downloadSpeed: 1);
      final inactive = _torrent(downloadSpeed: 0);

      expect(active.isActivelyDownloading, isTrue);
      expect(inactive.isActivelyDownloading, isFalse);
    });

    test('classifies checking and waiting from torrent state', () {
      final checking = _torrent(state: TorrentState.checking);
      final waiting = _torrent(state: TorrentState.queued);

      expect(checking.isChecking, isTrue);
      expect(checking.isWaiting, isFalse);
      expect(waiting.isChecking, isFalse);
      expect(waiting.isWaiting, isTrue);
    });
  });
}
