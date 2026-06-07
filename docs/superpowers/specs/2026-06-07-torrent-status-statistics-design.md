# Torrent Status and Statistics Design

Date: 2026-06-07

## Goal

Update torrent status classification and statistics so the app reports errors, active uploads, active downloads, checking torrents, and waiting torrents consistently across the home statistics and torrent filtering.

The confirmed rules are:

- A torrent is considered to have a tracker error when none of its tracker status messages contains `Success`.
- A torrent is actively uploading when `uploadSpeed > 0`.
- A torrent is actively downloading when `downloadSpeed > 0`.
- A torrent is checking when its state is `TorrentState.checking`.
- A torrent is waiting when its state is `TorrentState.queued`.

## Current State

`Torrent` currently stores tracker URLs in `trackers`, but it does not store tracker status messages. Error logic is split across the app:

- `Torrent.isError` only checks `state == TorrentState.error`.
- `TorrentProvider.errorCount` treats `error` and `unknown` states as errors.
- `StatsProvider` counts client errors using only `TorrentState.error`.
- Global statistics use the old `Torrent.isError` rule.

This can make the home statistics, error tab, and torrent model disagree about whether a torrent is in error.

## Approach

Use the selected model-centered approach. `Torrent` becomes the single source of truth for derived status classification. Providers and UI consume those derived properties instead of reimplementing status rules.

## Data Model

Keep the existing `trackers: List<String>` field for tracker URLs and site filtering. Add a new field:

```dart
List<String> trackerStatuses;
```

This field stores tracker status or message text returned by the client service.

Add derived getters to `Torrent`:

- `hasSuccessfulTracker`: true when any tracker status contains `Success`.
- `hasTrackerError`: true when `hasSuccessfulTracker` is false.
- `isError`: true when the torrent state is `error` or `unknown`, or when `hasTrackerError` is true.
- `isActivelyUploading`: true when `uploadSpeed > 0`.
- `isActivelyDownloading`: true when `downloadSpeed > 0`.
- `isChecking`: true when state is `checking`.
- `isWaiting`: true when state is `queued`.

If `trackerStatuses` is empty, `hasSuccessfulTracker` is false and `hasTrackerError` is true. This matches the confirmed rule that a torrent without any `Success` tracker status counts as an error.

## Service Parsing

### qBittorrent

`QBittorrentService.getTorrents()` currently maps torrent list rows into `Torrent` objects and only captures the current tracker URL. To populate tracker statuses, it should fetch tracker details for each torrent hash using the existing tracker endpoint logic and collect each tracker's message/status into `trackerStatuses`.

The first implementation prioritizes correctness. It may issue one tracker request per torrent. If this causes slow refreshes for large torrent lists, a later optimization can add caching, throttling, or a lower-cost API source if available.

### Transmission

`TransmissionService.getTorrents()` should parse tracker announce status/result fields when present and populate `trackerStatuses`. If Transmission returns no usable tracker message for a torrent, the list remains empty and the torrent is classified as an error by the shared model rule.

## Statistics

`StatsProvider.refreshStats()` should use the new `Torrent` getters for all derived status counts.

Per-client counts:

- `downloadingCount`: count torrents where `isActivelyDownloading` is true.
- `uploadingCount`: count torrents where `isActivelyUploading` is true.
- `seedingCount`: count torrents where `isSeeding` is true.
- `pausedUpCount`: count paused complete torrents.
- `pausedDlCount`: count paused incomplete torrents.
- `errorCount`: count torrents where `isError` is true.
- `checkingCount`: count torrents where `isChecking` is true.
- `waitingCount`: count torrents where `isWaiting` is true.

Global statistics should also include:

- `uploadingCount`
- `checkingCount`
- `waitingCount`

Existing global fields should be updated to the same model rules:

- `downloadingCount` uses `isActivelyDownloading`.
- `errorCount` uses `isError`.

## Filtering and UI

`TorrentProvider.errorCount` and the error tab/filter should use `Torrent.isError`, so tracker errors are visible in the same places as state-based errors.

Home UI should consume statistics from `GlobalStats` and `ClientStats` without duplicating classification logic. If the client card does not already display active uploads, add a display item for `uploadingCount`.

No complex tracker or speed classification should be implemented in widgets.

## Testing and Verification

Add or update tests for the shared model rules:

- Tracker status list containing `Success` is not a tracker error.
- Tracker status list without `Success` is a tracker error.
- Empty tracker status list is a tracker error.
- `uploadSpeed > 0` means actively uploading.
- `downloadSpeed > 0` means actively downloading.
- `TorrentState.checking` means checking.
- `TorrentState.queued` means waiting.

Also verify provider-level behavior where practical:

- Global and client error counts use `Torrent.isError`.
- Global and client active download counts use `isActivelyDownloading`.
- Uploading, checking, and waiting counts are populated correctly.

Run:

```bash
flutter analyze
flutter test
```

## Scope

This design changes classification, statistics, and minimal UI display for the new counts. It does not add advanced tracker diagnostics, retry controls, historical status tracking, or performance optimization beyond preserving existing behavior where possible.
