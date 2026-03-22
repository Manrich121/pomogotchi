# Contract: Local Data Boundary

## Purpose

Define the persistence operations that the application layer may rely on from the PowerSync-backed local store.

## Runtime Mode

- Version 1 uses a single initialized `PowerSyncDatabase` instance without calling `connect()`.
- Pomogotchi tables are implemented as local-only tables so anonymous local writes do not accumulate in the PowerSync upload queue.
- Application queries must target the schema-defined table views, not PowerSync internal `ps_*` tables.

## Repository Capabilities

### Session Operations

- `loadActiveSession() -> SessionRecord?`
- `createSession(type, startedAt, plannedDurationSeconds, dayKey) -> SessionRecord`
- `pauseSession(sessionId, pausedAt, remainingSecondsAtPause) -> SessionRecord`
- `resumeSession(sessionId, resumedAt) -> SessionRecord`
- `endSession(sessionId, endedAt, outcome) -> SessionRecord`
- `watchTodaySessions(dayKey) -> Stream<List<SessionRecord>>`

### Wellness Operations

- `addWellnessEvent(type, occurredAt, dayKey) -> WellnessEvent`
- `watchTodayWellnessEvents(dayKey) -> Stream<List<WellnessEvent>>`

### Summary Operations

- `loadOrCreateDailySummary(dayKey, openedAt) -> DailyActivitySummary`
- `refreshDailySummary(dayKey, now) -> DailyActivitySummary`
- `setHydrationReminderState(dayKey, anchorAt, isActive) -> DailyActivitySummary`
- `watchDailySummary(dayKey) -> Stream<DailyActivitySummary>`

## Query and Mutation Rules

- Use `getOptional` or an equivalent single-row read for active-session and single-summary lookups.
- Use `getAll` for non-reactive list reads.
- Use `watch` for UI-facing reactive queries such as current-day summary totals and active-session state.
- Use `execute` for single-table writes that do not require atomic coordination with other tables.
- Use `writeTransaction` for any operation that updates more than one table or row set as one logical action.
- Generate client-side UUIDs for inserted rows even in local-only mode so later sync remains possible.

## Behavioral Guarantees

- Reads after a successful write in the same app session must reflect the latest stored state.
- At most one active or paused session may be returned by `loadActiveSession`.
- Ending a session must update the corresponding daily total before observers are notified.
- Adding a hydration event must clear any active reminder and reset the hydration timer anchor in the summary before observers are notified.
- Daily summary creation for a new day must not delete an in-progress session record required to restore the UI accurately.

## Failure Contract

- Persistence failures must surface a typed error to the application layer so the UI can enter the defined error state.
- Corrupt or incomplete persisted session data must be rejected rather than partially applied.
- The application layer may retry idempotent reads and summary refreshes after a failure, but duplicate writes must be prevented for event logging and session completion.
- The application layer must not rely on deleting PowerSync internal queue tables as a normal control path for version 1.
