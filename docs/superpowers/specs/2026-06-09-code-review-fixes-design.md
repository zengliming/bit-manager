# Code Review Fixes Design

Date: 2026-06-09

## Goal

Fix the confirmed review findings from the current optimization diff while keeping the implementation focused and low risk. The work should correct real behavior bugs, preserve the intended performance improvements where possible, and add regression tests around the changed behavior.

## Scope

In scope:

- Make RSS duplicate detection safe across concurrent refresh/auto-download operations.
- Prevent duplicate submissions within a single RSS auto-download pass after a successful add.
- Fix global `activeTorrents` so each active torrent is counted once.
- Replace `StatsProvider`'s untyped `Map<String, dynamic>` per-client result with a type-safe structure.
- Ensure cached Dio clients do not retain stale timeout/client configuration after edits.
- Cancel `TorrentProvider`'s search debounce timer during disposal.
- Keep `_searchQueryLowerCase` in sync when clearing filters.
- Tighten batch operation behavior where missing Transmission hashes were previously silent.
- Add or update focused tests for the fixes.

Out of scope:

- Large provider/service architecture changes.
- Replacing the full RSS/TorrentProvider data flow with a shared cache layer.
- Rewriting all qBittorrent/Transmission operations into a common abstraction.
- UI redesign.

## Approach

Use a focused repair with small adjacent cleanups. Avoid broad refactors. Prefer local data snapshots, explicit invalidation, and type-safe return structures.

## RSS duplicate detection

`RssProvider` currently stores prefetched torrents in a provider-level `_torrentsCache`. Both manual RSS item refresh and background auto-download mutate this same map. The fix is to remove that shared mutable cache from the control flow:

- Change `_prefetchTorrents(List<ClientConfig>)` to return `Map<String, List<Torrent>>`.
- Pass that local snapshot into `_isDuplicateFromCache(...)`.
- Let `fetchItems()` and `processAutoDownloads()` each hold their own snapshot, so concurrent calls cannot clear or overwrite each other.

For auto-downloads, keep the one-prefetch-per-pass optimization but add a local in-pass guard for successfully submitted RSS items. After `addTorrentFromUrl()` succeeds, record enough data from the RSS item (`guid`, `link`, and `title`) to prevent later items in the same pass from being submitted again when they clearly refer to the same content. This guard supplements, but does not replace, the client torrent snapshot.

Errors remain isolated: one source or one item failing should not abort the whole auto-download pass.

## StatsProvider counting and typing

`activeTorrents` must keep the model-level OR semantics from `Torrent.isActive`. The new summed counters double-count torrents that are both downloading and uploading. The fix is:

- Compute `activeTorrents` with `allTorrents.where((t) => t.isActive).length`.
- Keep independent `downloadingCount` and `uploadingCount` totals as separate counters that may overlap.
- Replace the `Map<String, dynamic>` returned from the `Future.wait` branch with a typed result. Prefer a Dart record if the current SDK supports it; otherwise use a private `_ClientStatsRefreshResult` class.

This keeps global counts correct and lets the compiler catch field/type mistakes.

## HTTP client cache invalidation

`HttpClientUtil.createClientDio()` currently caches by `baseUrl` only, so changing `timeoutSeconds` on a client with the same host/port returns the old Dio instance.

The cache should be corrected in two layers:

- Include configuration that affects the Dio instance in the cache key, at minimum `baseUrl` and `timeoutSeconds`.
- Call `HttpClientUtil.instance.clearClientDioCache()` after client add, update, or delete in `ClientProvider` so user edits apply immediately.

This preserves connection reuse while avoiding stale configuration after settings changes.

## TorrentProvider debounce and filter state

`TorrentProvider.setSearchQuery()` creates a debounce timer that calls `notifyListeners()`. Add a `dispose()` override that cancels `_searchDebounce` before calling `super.dispose()`.

Also update `clearAllFilters()` so it resets both `_searchQuery` and `_searchQueryLowerCase`. This keeps the cached lowercase query consistent with the displayed search query.

The existing `_errorCount` cache can remain if all current `_allTorrents` mutations still go through `refreshTorrents()`. Do not expand this into unrelated state-management refactoring.

## Batch operation behavior

Keep the batch API performance improvement. Avoid silently succeeding when requested hashes cannot be resolved in Transmission:

- qBittorrent batch operations continue using the native batch endpoints and `hashes.join('|')`.
- Transmission batch operations resolve hashes to IDs once. If the caller provided hashes and not all are resolved, throw a clear exception instead of silently operating on a subset.
- Small private helpers may be introduced if they reduce duplication without changing behavior broadly.

## Testing

Add or update focused tests for:

- RSS concurrent/local-cache behavior: manual refresh and auto-download should not share mutable cache state.
- RSS in-pass duplicate guard after successful auto-download.
- `StatsProvider.activeTorrents` counts a torrent with both download and upload speed once.
- Stats per-client aggregation remains type-safe and produces the same totals.
- `HttpClientUtil` returns a Dio with updated timeout after config changes or distinct cache keys.
- `ClientProvider` invalidates the Dio cache after add/update/delete.
- `TorrentProvider.dispose()` cancels a pending search debounce timer.
- `clearAllFilters()` clears the cached lowercase search query effect.
- Transmission batch operations fail clearly when hashes cannot be resolved.

Run the relevant Flutter tests after implementation. Run the full test suite if feasible.

## Success criteria

- The five confirmed review findings are fixed.
- Adjacent agreed cleanups are implemented with small, focused diffs.
- Existing public behavior is preserved except where the bug fix intentionally changes it.
- Regression tests cover the corrected behavior.
- No broad architecture migration is introduced in this change.
