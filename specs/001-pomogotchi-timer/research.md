# Research: Pomogotchi PowerSync Implementation

This document focuses on PowerSync-specific implementation research for the current plan, especially SDK usage, client-side schemas, and query patterns.

## Research Gap 1: Whether version 1 should connect to PowerSync

- **Plan area affected**: Technical Context, repository implementation, backend scope.
- **Findings**:
  - PowerSync can be used as a local SQLite layer without calling `connect()`.
  - PowerSync's local-only guidance recommends local-only tables for pre-login or anonymous flows so local writes do not accumulate indefinitely in the upload queue.
  - Deleting PowerSync internal queue tables is not the intended control path for this problem.
- **Decision**: Version 1 should initialize `PowerSyncDatabase` locally and not call `connect()`. Pomogotchi data should live in local-only tables.
- **Implementation impact**:
  - No backend connector, token fetch, or `uploadData()` implementation is required in this release.
  - `sessions`, `wellness_events`, and `daily_activity_summary` should all be local-only tables.
  - Introducing real sync later becomes a separate migration task.
- **Alternatives considered**:
  - Use synced tables immediately and let the queue grow; rejected because the official local-only guidance is a better fit for a no-login release.
  - Build backend sync now; rejected because the spec has no backend or authentication scope.
- **Sources**:
  - PowerSync Flutter SDK reference: https://docs.powersync.com/client-sdks/reference/flutter
  - Local-Only Usage: https://docs.powersync.com/client-sdks/advanced/local-only-usage

## Research Gap 2: How the client-side schema should be modeled

- **Plan area affected**: `schema.dart`, data model, indexing strategy.
- **Findings**:
  - The schema is supplied when constructing `PowerSyncDatabase`.
  - PowerSync automatically adds an `id` column of type `text`, so it should not be declared manually.
  - Supported schema column types are `text`, `integer`, and `real`.
  - Client schemas are applied as SQLite views, so normal client-side schema changes do not require a traditional migration system.
  - Indexes can and should be declared for common query paths.
- **Decision**: Add a dedicated `schema.dart` with three local-only tables and indexes tuned for current-day and active-session lookups.
- **Implementation impact**:
  - Persist timestamps as `text`.
  - Persist counters, durations, boolean-like flags, and reminder state as `integer`.
  - Add indexes on fields such as `day_key`, `state`, and `type`.
- **Alternatives considered**:
  - Leave all tables unindexed initially; rejected because the home screen repeatedly loads active-session and current-day data.
  - Use raw tables immediately; rejected because PowerSync's default schema views are enough for this scope and raw tables are documented as experimental.
- **Sources**:
  - Setup Guide / Define your client-side schema: https://docs.powersync.com/intro/setup-guide#define-your-client-side-schema
  - Client Architecture: https://docs.powersync.com/architecture/client-architecture

## Research Gap 3: Which query APIs should the Flutter app actually use

- **Plan area affected**: repository contract, controller behavior, reactive UI.
- **Findings**:
  - Standard reads use SQL helpers such as `get`, `getOptional`, and `getAll`.
  - Reactive updates in Flutter use `db.watch(...)` to stream query results when dependent tables change.
  - The app always reads from the local SQLite store, regardless of sync status.
  - The general watch-query documentation mentions a newer `db.query.watch()` direction, but the Flutter SDK reference still documents the established `db.watch(...)` API for Dart/Flutter usage.
- **Decision**: Use `db.watch(...)` for persisted-state streams and keep the one-second countdown in memory rather than writing or re-querying every second.
- **Implementation impact**:
  - `watchDailySummary` and `watchTodaySessions` should be backed by `db.watch(...)`.
  - `loadActiveSession` should use a single-row read such as `getOptional(...)`.
  - The timer UI should derive remaining time from timestamps plus an injected clock.
- **Alternatives considered**:
  - Poll the database or write countdown values continuously; rejected because that adds unnecessary persistence churn and increases drift risk.
  - Use only imperative reads; rejected because the UI needs live updates when logging events and changing session state.
- **Sources**:
  - Reading Data: https://docs.powersync.com/client-sdks/reading-data
  - Live Queries / Watch Queries: https://docs.powersync.com/client-sdks/watch-queries
  - PowerSync Flutter SDK reference: https://docs.powersync.com/client-sdks/reference/flutter

## Research Gap 4: How writes should be grouped

- **Plan area affected**: session transitions, summary updates, repository atomicity.
- **Findings**:
  - Single SQL mutations can use `execute(...)`.
  - Related writes should use `writeTransaction(...)` so the changes commit together or roll back together.
  - PowerSync recommends UUIDs for client-created rows.
  - If sync is enabled later, writes are translated into upload queue records such as `PUT`, `PATCH`, and `DELETE`.
- **Decision**: Use `execute(...)` for isolated single-table writes and `writeTransaction(...)` for any multi-step session or summary transition.
- **Implementation impact**:
  - Session start can be one insert.
  - Session end plus summary increment should run in one transaction.
  - Hydration log plus reminder reset should run in one transaction.
  - Client-created IDs should be UUIDs even in local-only mode.
- **Alternatives considered**:
  - Split session writes and summary writes across separate operations; rejected because partial failure would leave the UI inconsistent.
- **Sources**:
  - Writing Data: https://docs.powersync.com/client-sdks/writing-data
  - Usage Examples: https://docs.powersync.com/client-sdks/usage-examples

## Research Gap 5: What lifecycle and status APIs the architecture should preserve

- **Plan area affected**: app bootstrap, future sync readiness, debugging.
- **Findings**:
  - PowerSync recommends a single database instance per database file.
  - Flutter exposes `currentStatus` and `statusStream` for sync and connection status.
  - `hasSynced`, `waitForFirstSync()`, and `downloadProgress` exist for connected-sync flows.
- **Decision**: Centralize database ownership in one app-level service now, while deferring visible sync-status UI until a later authenticated release.
- **Implementation impact**:
  - App bootstrap should create and share one `PowerSyncDatabase`.
  - Repository instances should depend on that shared database instead of constructing their own.
  - Future sync-status UI can be added without restructuring the whole feature.
- **Alternatives considered**:
  - Ignore status APIs entirely; rejected because centralizing database ownership is cheap now and avoids later churn.
- **Sources**:
  - PowerSync Flutter SDK reference: https://docs.powersync.com/client-sdks/reference/flutter
  - Usage Examples: https://docs.powersync.com/client-sdks/usage-examples

## Research Gap 6: What PowerSync requires for testing

- **Plan area affected**: repository tests, local setup, CI readiness.
- **Findings**:
  - PowerSync's unit-testing guidance requires the `powersync-sqlite-core` binary in the project root for tests that instantiate the SDK directly.
  - The documented test setup uses a real initialized PowerSync database against a temporary file.
- **Decision**: Keep timer and reminder rules outside PowerSync so most tests stay pure Dart, and limit PowerSync-backed tests to repository integration paths.
- **Implementation impact**:
  - Domain logic tests should not require the PowerSync runtime.
  - If repository tests are added, developer setup and CI need the documented binary.
- **Alternatives considered**:
  - Put all persistence tests through live PowerSync from the start; rejected because it raises setup cost for logic that does not need SDK coverage.
- **Sources**:
  - Unit Testing: https://docs.powersync.com/client-sdks/advanced/unit-testing
  - PowerSync Flutter package: https://pub.dev/packages/powersync
