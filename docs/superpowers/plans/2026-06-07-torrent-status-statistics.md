# Torrent Status Statistics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make torrent error, upload, download, checking, and waiting statistics follow the confirmed tracker/status/speed rules consistently across models, providers, and the home UI.

**Architecture:** `Torrent` becomes the single source of truth for derived status classification. Client services populate tracker status messages, providers consume `Torrent` getters, and widgets display provider statistics without duplicating classification logic.

**Tech Stack:** Flutter, Dart, Provider, `flutter_test`, qBittorrent Web API, Transmission RPC.

---

## File Structure

- Modify: `lib/models/torrent.dart`
  - Add `trackerStatuses` and derived status getters.
  - Keep `trackers` unchanged for URL/site filtering compatibility.
- Modify: `lib/models/stats.dart`
  - Add `uploadingCount`, `checkingCount`, and `waitingCount` to `GlobalStats`.
  - Add `uploadingCount` to `ClientStats`.
- Modify: `lib/providers/torrent_provider.dart`
  - Make error count, error tab, and error-only filter use `Torrent.isError`.
- Modify: `lib/providers/stats_provider.dart`
  - Use the new `Torrent` getters for all status counts.
  - Populate the new global/client count fields.
- Modify: `lib/services/qbittorrent_service.dart`
  - Collect tracker messages from `getTrackers()` for each torrent and store them in `trackerStatuses`.
- Modify: `lib/services/transmission_service.dart`
  - Request `trackerStats` in `getTorrents()` and parse tracker messages into `trackerStatuses`.
- Modify: `lib/widgets/client_tile.dart`
  - Add an upload count pill and display checking/waiting counts already present in `ClientStats`.
- Create: `test/models/torrent_test.dart`
  - Unit tests for model-level status rules.
- Create: `test/models/stats_test.dart`
  - Constructor/default tests for new stats fields.

---

### Task 1: Add Torrent Classification Tests

**Files:**
- Create: `test/models/torrent_test.dart`
- Modify later: `lib/models/torrent.dart`

- [ ] **Step 1: Create failing model tests**

Create `test/models/torrent_test.dart` with this full content:

```dart
import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/models/torrent.dart';
import 'package:flutter_test/flutter_test.dart';

Torrent _torrent({
  TorrentState state = TorrentState.downloading,
  int downloadSpeed = 0,
  int uploadSpeed = 0,
  List<String> trackerStatuses = const ['Success'],
}) {
  return Torrent(
    id: 'torrent-1',
    hash: 'hash-1',
    name: 'Torrent 1',
    clientId: 'client-1',
    clientType: ClientType.qbittorrent,
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
flutter test test/models/torrent_test.dart
```

Expected: FAIL with errors like `No named parameter with the name 'trackerStatuses'`, `The getter 'hasSuccessfulTracker' isn't defined`, and `The getter 'isActivelyUploading' isn't defined`.

- [ ] **Step 3: Commit the failing tests**

```bash
git add test/models/torrent_test.dart
git commit -m "test: add torrent status classification tests"
```

---

### Task 2: Implement Torrent Classification Getters

**Files:**
- Modify: `lib/models/torrent.dart`
- Test: `test/models/torrent_test.dart`

- [ ] **Step 1: Update `Torrent` model**

Replace the `Torrent` class body in `lib/models/torrent.dart` with this content, keeping the existing `import 'client_config.dart';` and `TorrentState` enum unchanged:

```dart
class Torrent {
  final String id;
  final String hash;
  String name;
  final String clientId;
  final ClientType clientType;
  double progress;
  TorrentState state;
  int downloadSpeed;
  int uploadSpeed;
  int downloaded;
  int uploaded;
  int totalSize;
  double ratio;
  int peersConnected;
  int seedsConnected;
  int peersTotal;
  int seedsTotal;
  int eta;
  String? error;
  String? savePath;
  DateTime? addedAt;
  DateTime? completedAt;
  List<String> trackers;
  List<String> trackerStatuses;

  Torrent({
    required this.id,
    required this.hash,
    required this.name,
    required this.clientId,
    required this.clientType,
    this.progress = 0,
    this.state = TorrentState.unknown,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.downloaded = 0,
    this.uploaded = 0,
    this.totalSize = 0,
    this.ratio = 0,
    this.peersConnected = 0,
    this.seedsConnected = 0,
    this.peersTotal = 0,
    this.seedsTotal = 0,
    this.eta = 0,
    this.error,
    this.savePath,
    this.addedAt,
    this.completedAt,
    this.trackers = const [],
    this.trackerStatuses = const [],
  });

  bool get hasSuccessfulTracker => trackerStatuses.any((status) => status.contains('Success'));
  bool get hasTrackerError => !hasSuccessfulTracker;
  bool get isActivelyUploading => uploadSpeed > 0;
  bool get isActivelyDownloading => downloadSpeed > 0;
  bool get isChecking => state == TorrentState.checking;
  bool get isWaiting => state == TorrentState.queued;

  bool get isDownloading => state == TorrentState.downloading || state == TorrentState.metaDL;
  bool get isSeeding => state == TorrentState.seeding;
  bool get isPaused => state == TorrentState.paused;
  bool get isComplete => progress >= 1.0;
  bool get isError => state == TorrentState.error || state == TorrentState.unknown || hasTrackerError;
  bool get isActive => isActivelyDownloading || isActivelyUploading || isChecking;
}
```

- [ ] **Step 2: Run model tests**

Run:

```bash
flutter test test/models/torrent_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run analyzer for the model change**

Run:

```bash
flutter analyze
```

Expected: no new errors from `lib/models/torrent.dart`.

- [ ] **Step 4: Commit the model implementation**

```bash
git add lib/models/torrent.dart test/models/torrent_test.dart
git commit -m "feat: centralize torrent status classification"
```

---

### Task 3: Add Stats Model Fields and Tests

**Files:**
- Modify: `lib/models/stats.dart`
- Create: `test/models/stats_test.dart`

- [ ] **Step 1: Create failing stats tests**

Create `test/models/stats_test.dart` with this full content:

```dart
import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/models/stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GlobalStats exposes active upload, checking, and waiting counts', () {
    final stats = GlobalStats(
      uploadingCount: 2,
      checkingCount: 3,
      waitingCount: 4,
    );

    expect(stats.uploadingCount, 2);
    expect(stats.checkingCount, 3);
    expect(stats.waitingCount, 4);
  });

  test('GlobalStats new count fields default to zero', () {
    final stats = GlobalStats();

    expect(stats.uploadingCount, 0);
    expect(stats.checkingCount, 0);
    expect(stats.waitingCount, 0);
  });

  test('ClientStats exposes active upload count', () {
    final stats = ClientStats(
      clientId: 'client-1',
      clientName: 'Client 1',
      type: ClientType.qbittorrent,
      uploadingCount: 5,
    );

    expect(stats.uploadingCount, 5);
  });

  test('ClientStats active upload count defaults to zero', () {
    final stats = ClientStats(
      clientId: 'client-1',
      clientName: 'Client 1',
      type: ClientType.qbittorrent,
    );

    expect(stats.uploadingCount, 0);
  });
}
```

- [ ] **Step 2: Run stats tests to verify they fail**

Run:

```bash
flutter test test/models/stats_test.dart
```

Expected: FAIL with errors like `No named parameter with the name 'uploadingCount'` and `The getter 'checkingCount' isn't defined for the type 'GlobalStats'`.

- [ ] **Step 3: Add stats fields**

In `lib/models/stats.dart`, update `GlobalStats` to include the new fields. The class should look like this:

```dart
class GlobalStats {
  int totalTorrents;
  int activeTorrents;
  int downloadingCount;
  int uploadingCount;
  int seedingCount;
  int pausedCount;
  int errorCount;
  int checkingCount;
  int waitingCount;
  int downloadSpeed;
  int uploadSpeed;
  int totalDownloaded;
  int totalUploaded;
  int totalSizeOnDisk;
  List<ClientStats> clientStatsList;

  GlobalStats({
    this.totalTorrents = 0,
    this.activeTorrents = 0,
    this.downloadingCount = 0,
    this.uploadingCount = 0,
    this.seedingCount = 0,
    this.pausedCount = 0,
    this.errorCount = 0,
    this.checkingCount = 0,
    this.waitingCount = 0,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.totalDownloaded = 0,
    this.totalUploaded = 0,
    this.totalSizeOnDisk = 0,
    this.clientStatsList = const [],
  });
}
```

Then add `uploadingCount` to `ClientStats` immediately after `downloadingCount`. The relevant part should look like this:

```dart
  // 各状态计数
  int downloadingCount;
  int uploadingCount;
  int seedingCount;
  int pausedUpCount;
  int pausedDlCount;
  int errorCount;
  int checkingCount;
  int waitingCount;
```

And the constructor parameter list should include:

```dart
    this.downloadingCount = 0,
    this.uploadingCount = 0,
    this.seedingCount = 0,
```

- [ ] **Step 4: Run stats tests**

Run:

```bash
flutter test test/models/stats_test.dart
```

Expected: PASS.

- [ ] **Step 5: Run existing widget smoke test**

Run:

```bash
flutter test test/widget_test.dart
```

Expected: PASS. If it fails because a widget now expects a new required constructor parameter, make the parameter optional with a default of `0` as shown above, then re-run.

- [ ] **Step 6: Commit stats model changes**

```bash
git add lib/models/stats.dart test/models/stats_test.dart
git commit -m "feat: add upload checking waiting stats fields"
```

---

### Task 4: Update Provider Statistics and Filtering

**Files:**
- Modify: `lib/providers/stats_provider.dart`
- Modify: `lib/providers/torrent_provider.dart`
- Test: `test/models/torrent_test.dart`, `test/models/stats_test.dart`, `test/widget_test.dart`

- [ ] **Step 1: Update torrent provider error logic**

In `lib/providers/torrent_provider.dart`, replace the error-only filter block:

```dart
    if (_errorOnly) {
      result = result.where((t) => t.error != null && t.error!.isNotEmpty).toList();
    }
```

with:

```dart
    if (_errorOnly) {
      result = result.where((t) => t.isError).toList();
    }
```

Replace the `errorCount` getter:

```dart
  int get errorCount => _allTorrents
      .where((t) => t.state == TorrentState.error || t.state == TorrentState.unknown)
      .length;
```

with:

```dart
  int get errorCount => _allTorrents.where((t) => t.isError).length;
```

Replace the error tab state filter case:

```dart
      case 2:
        _stateFilter = {TorrentState.error, TorrentState.unknown};
        break;
```

with:

```dart
      case 2:
        _stateFilter = null;
        _errorOnly = true;
        break;
```

Also update the all tab case so it clears `_errorOnly`:

```dart
      case 0:
        _stateFilter = null;
        _errorOnly = false;
        break;
```

And update the download and seeding tab cases so they clear `_errorOnly`:

```dart
      case 1:
        _stateFilter = {TorrentState.downloading, TorrentState.metaDL};
        _errorOnly = false;
        break;
      case 3:
        _stateFilter = {TorrentState.seeding};
        _errorOnly = false;
        break;
```

- [ ] **Step 2: Update stats provider count loop**

In `lib/providers/stats_provider.dart`, replace this declaration:

```dart
        int downloading = 0, seeding = 0, pausedUp = 0, pausedDl = 0, error = 0, checking = 0, waiting = 0;
```

with:

```dart
        int downloading = 0, uploading = 0, seeding = 0, pausedUp = 0, pausedDl = 0, error = 0, checking = 0, waiting = 0;
```

Replace the `for (final t in clientTorrents)` status-count body with this version:

```dart
        for (final t in clientTorrents) {
          seedsConnected += t.seedsConnected;
          if (t.isActivelyDownloading) downloading++;
          if (t.isActivelyUploading) uploading++;
          if (t.isSeeding) seeding++;
          if (t.isPaused) {
            if (t.isComplete) {
              pausedUp++;
            } else {
              pausedDl++;
            }
          }
          if (t.isError) error++;
          if (t.isChecking) checking++;
          if (t.isWaiting) waiting++;
        }
```

Add `uploadingCount: uploading,` to the `ClientStats` constructor immediately after `downloadingCount: downloading,`:

```dart
          downloadingCount: downloading,
          uploadingCount: uploading,
          seedingCount: seeding,
```

Update `_globalStats = GlobalStats(...)` so these fields use model getters:

```dart
      _globalStats = GlobalStats(
        totalTorrents: allTorrents.length,
        activeTorrents: allTorrents.where((t) => t.isActive).length,
        downloadingCount: allTorrents.where((t) => t.isActivelyDownloading).length,
        uploadingCount: allTorrents.where((t) => t.isActivelyUploading).length,
        seedingCount: allTorrents.where((t) => t.isSeeding).length,
        pausedCount: allTorrents.where((t) => t.isPaused).length,
        errorCount: allTorrents.where((t) => t.isError).length,
        checkingCount: allTorrents.where((t) => t.isChecking).length,
        waitingCount: allTorrents.where((t) => t.isWaiting).length,
        downloadSpeed: downloadSpeed,
        uploadSpeed: uploadSpeed,
        totalDownloaded: totalDownloaded,
        totalUploaded: totalUploaded,
        totalSizeOnDisk: totalSize,
        clientStatsList: clientStatsList,
      );
```

- [ ] **Step 3: Run model and widget tests**

Run:

```bash
flutter test test/models/torrent_test.dart test/models/stats_test.dart test/widget_test.dart
```

Expected: PASS.

- [ ] **Step 4: Run analyzer**

Run:

```bash
flutter analyze
```

Expected: no errors from `stats_provider.dart` or `torrent_provider.dart`.

- [ ] **Step 5: Commit provider changes**

```bash
git add lib/providers/stats_provider.dart lib/providers/torrent_provider.dart
git commit -m "feat: use unified torrent status stats"
```

---

### Task 5: Populate Tracker Statuses in Client Services

**Files:**
- Modify: `lib/services/qbittorrent_service.dart`
- Modify: `lib/services/transmission_service.dart`
- Test: `test/models/torrent_test.dart`, `test/widget_test.dart`

- [ ] **Step 1: Update qBittorrent torrent parsing**

In `lib/services/qbittorrent_service.dart`, change `getTorrents()` from returning `rawList.map(...).toList()` to building the list in a loop so each torrent can fetch trackers.

Replace the body from line beginning `return rawList.map((json) {` through the matching `.toList();` with this implementation:

```dart
    final torrents = <Torrent>[];
    for (final json in rawList) {
      final m = (json is Map<String, dynamic>) ? json : <String, dynamic>{};
      final hash = m['hash'] as String? ?? '';
      final trackers = (m['tracker'] as String?) != null && (m['tracker'] as String).isNotEmpty
          ? [(m['tracker'] as String)]
          : <String>[];
      final trackerStatuses = <String>[];
      if (hash.isNotEmpty) {
        try {
          final trackerInfos = await getTrackers(config, hash);
          trackerStatuses.addAll(trackerInfos.map((tracker) => tracker.status));
          if (trackers.isEmpty) {
            trackers.addAll(trackerInfos.map((tracker) => tracker.url).where((url) => url.isNotEmpty));
          }
        } catch (_) {}
      }

      torrents.add(Torrent(
        id: hash,
        hash: hash,
        name: m['name'] as String? ?? 'Unknown',
        clientId: config.id,
        clientType: config.type,
        progress: (m['progress'] as num?)?.toDouble() ?? 0,
        state: _mapState(m['state'] as String? ?? ''),
        downloadSpeed: (m['dlspeed'] as num?)?.toInt() ?? 0,
        uploadSpeed: (m['upspeed'] as num?)?.toInt() ?? 0,
        downloaded: (m['downloaded'] as num?)?.toInt() ?? 0,
        uploaded: (m['uploaded'] as num?)?.toInt() ?? 0,
        totalSize: (m['total_size'] as num?)?.toInt() ?? 0,
        ratio: (m['ratio'] as num?)?.toDouble() ?? 0,
        peersConnected: (m['num_leechs'] as num?)?.toInt() ?? 0,
        seedsConnected: (m['num_seeds'] as num?)?.toInt() ?? 0,
        peersTotal: (m['num_incomplete'] as num?)?.toInt() ?? 0,
        seedsTotal: (m['num_complete'] as num?)?.toInt() ?? 0,
        eta: (m['eta'] as num?)?.toInt() ?? 0,
        error: m['error'] as String?,
        savePath: m['save_path'] as String?,
        trackers: trackers,
        trackerStatuses: trackerStatuses,
        addedAt: (m['added_on'] as num?) != null
            ? DateTime.fromMillisecondsSinceEpoch((m['added_on'] as int) * 1000)
            : null,
        completedAt: (m['completion_on'] as num?) != null && (m['completion_on'] as int) > 0
            ? DateTime.fromMillisecondsSinceEpoch((m['completion_on'] as int) * 1000)
            : null,
      ));
    }
    return torrents;
```

- [ ] **Step 2: Update Transmission requested fields**

In `lib/services/transmission_service.dart`, add `trackerStats` to the `fields` list in `getTorrents()` immediately after `trackerList`:

```dart
            'trackerList',
            'trackerStats',
```

- [ ] **Step 3: Add Transmission tracker-status parser**

In `lib/services/transmission_service.dart`, add this helper immediately after `_parseTrackerList`:

```dart
  List<String> _parseTrackerStatuses(dynamic trackerStatsRaw) {
    final stats = (trackerStatsRaw is List) ? trackerStatsRaw : <dynamic>[];
    return stats
        .map((s) => (s is Map<String, dynamic>) ? s['lastAnnounceResult'] as String? ?? '' : '')
        .where((status) => status.isNotEmpty)
        .toList();
  }
```

- [ ] **Step 4: Populate Transmission tracker statuses**

In the `Torrent(` constructor inside `TransmissionService.getTorrents()`, add this argument immediately after `trackers: _parseTrackerList(...)`:

```dart
        trackerStatuses: _parseTrackerStatuses(m['trackerStats']),
```

The end of the constructor should look like this:

```dart
        completedAt: (m['doneDate'] as num?) != null &&
                (m['doneDate'] as int) > 0
            ? DateTime.fromMillisecondsSinceEpoch(
                (m['doneDate'] as int) * 1000)
            : null,
        trackers: _parseTrackerList(m['trackerList'] as String? ?? ''),
        trackerStatuses: _parseTrackerStatuses(m['trackerStats']),
      );
```

- [ ] **Step 5: Run tests and analyzer**

Run:

```bash
flutter test test/models/torrent_test.dart test/models/stats_test.dart test/widget_test.dart
flutter analyze
```

Expected: tests PASS and analyzer reports no errors from `qbittorrent_service.dart` or `transmission_service.dart`.

- [ ] **Step 6: Commit service parsing changes**

```bash
git add lib/services/qbittorrent_service.dart lib/services/transmission_service.dart
git commit -m "feat: populate torrent tracker statuses"
```

---

### Task 6: Display Upload, Checking, and Waiting Counts in Client Tile

**Files:**
- Modify: `lib/widgets/client_tile.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Add upload/checking/waiting pills**

In `lib/widgets/client_tile.dart`, inside the `Wrap(children: [...])` stat pills, insert an upload pill after the download pill:

```dart
                        _StatPill(
                          label: '上传',
                          value: stats.uploadingCount.toString(),
                          color: const Color(0xFF2196F3),
                        ),
```

Add checking and waiting pills after the error pill:

```dart
                        _StatPill(
                          label: '校验',
                          value: stats.checkingCount.toString(),
                          color: const Color(0xFF9C27B0),
                        ),
                        _StatPill(
                          label: '等待',
                          value: stats.waitingCount.toString(),
                          color: const Color(0xFF607D8B),
                        ),
```

The relevant section should contain this order:

```dart
                        _StatPill(
                          label: '做种',
                          value: stats.seedingCount.toString(),
                          color: const Color(0xFF2196F3),
                        ),
                        _StatPill(
                          label: '下载',
                          value: stats.downloadingCount.toString(),
                          color: const Color(0xFF4CAF50),
                        ),
                        _StatPill(
                          label: '上传',
                          value: stats.uploadingCount.toString(),
                          color: const Color(0xFF2196F3),
                        ),
                        _StatPill(
                          label: '错误',
                          value: stats.errorCount.toString(),
                          color: stats.errorCount > 0
                              ? const Color(0xFFE53935)
                              : Colors.grey,
                        ),
                        _StatPill(
                          label: '校验',
                          value: stats.checkingCount.toString(),
                          color: const Color(0xFF9C27B0),
                        ),
                        _StatPill(
                          label: '等待',
                          value: stats.waitingCount.toString(),
                          color: const Color(0xFF607D8B),
                        ),
```

- [ ] **Step 2: Run widget smoke test**

Run:

```bash
flutter test test/widget_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run analyzer**

Run:

```bash
flutter analyze
```

Expected: no errors from `client_tile.dart`.

- [ ] **Step 4: Commit UI change**

```bash
git add lib/widgets/client_tile.dart
git commit -m "feat: show expanded client status counts"
```

---

### Task 7: Full Verification

**Files:**
- Verify all modified files.

- [ ] **Step 1: Run complete test suite**

Run:

```bash
flutter test
```

Expected: all tests PASS, including:

- `test/models/torrent_test.dart`
- `test/models/stats_test.dart`
- `test/widget_test.dart`

- [ ] **Step 2: Run static analysis**

Run:

```bash
flutter analyze
```

Expected: `No issues found!` or only pre-existing warnings unrelated to these changes. If warnings appear in files changed by this plan, fix them before continuing.

- [ ] **Step 3: Inspect git diff for accidental scope creep**

Run:

```bash
git diff --stat HEAD~5..HEAD
git status --short
```

Expected: only intended files are modified or committed. The working tree may still contain pre-existing unrelated changes from before this work; do not include unrelated files in the feature commits.

- [ ] **Step 4: Final commit if verification fixes were needed**

If Step 1 or Step 2 required fixes, commit those fixes:

```bash
git add lib/models/torrent.dart lib/models/stats.dart lib/providers/stats_provider.dart lib/providers/torrent_provider.dart lib/services/qbittorrent_service.dart lib/services/transmission_service.dart lib/widgets/client_tile.dart test/models/torrent_test.dart test/models/stats_test.dart
git commit -m "fix: resolve torrent status statistics verification issues"
```

Expected: if no verification fixes were needed, skip this commit.

---

## Self-Review

- Spec coverage: The plan covers model tracker status storage, centralized getters, qBittorrent and Transmission parsing, provider statistics, error filtering, UI display, and verification commands.
- Placeholder scan: No task uses TBD/TODO or unspecified edge handling. Each code-changing task includes concrete code blocks and exact commands.
- Type consistency: Field and getter names are consistent across tasks: `trackerStatuses`, `hasSuccessfulTracker`, `hasTrackerError`, `isActivelyUploading`, `isActivelyDownloading`, `isChecking`, `isWaiting`, `uploadingCount`, `checkingCount`, and `waitingCount`.
