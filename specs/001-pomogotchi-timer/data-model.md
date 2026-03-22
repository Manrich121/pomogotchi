# Data Model: Pomogotchi Core Timer

## Overview

The feature persists only the current day's timer and wellness activity on-device. The model is designed for local-first reads and writes through a PowerSync-backed SQLite store while keeping domain rules independent from the persistence engine.

## Entities

### SessionRecord

- **Purpose**: Represents one focus or break session that has started and may be active, paused, completed, or stopped early.
- **Fields**:
  - `id`: Stable local identifier.
  - `dayKey`: Calendar-day key used for daily aggregation.
  - `type`: `focus` or `break`.
  - `plannedDurationSeconds`: Intended session duration in seconds. Version 1 defaults to `2400` for focus and `600` for break; future releases may allow user-configured values.
  - `state`: `active`, `paused`, or `ended`.
  - `outcome`: `completed` or `stopped`.
  - `startedAt`: Timestamp when the session began.
  - `lastResumedAt`: Timestamp of the most recent resume action.
  - `pausedAt`: Timestamp when the session entered paused state, if applicable.
  - `endedAt`: Timestamp when the session was completed or stopped.
  - `remainingSecondsAtPause`: Remaining time captured when paused.
- **Validation Rules**:
  - `plannedDurationSeconds` must be a positive integer. Version 1 application logic supplies `2400` for focus and `600` for break; the schema imposes no constraint on the value beyond positivity.
  - `ended` sessions must include `outcome` and `endedAt`.
  - `paused` sessions must include `pausedAt` and `remainingSecondsAtPause`.
  - Only one `active` or `paused` session may exist at a time for the device.

### WellnessEvent

- **Purpose**: Represents one hydration or movement log recorded by the user.
- **Fields**:
  - `id`: Stable local identifier.
  - `dayKey`: Calendar-day key used for daily aggregation.
  - `type`: `hydration` or `movement`.
  - `occurredAt`: Timestamp when the event was recorded.
- **Validation Rules**:
  - Events are append-only after creation.
  - `type` must be one of the two supported values in version 1.

### DailyActivitySummary

- **Purpose**: Holds the current day's derived counts and reminder anchors for fast UI rendering.
- **Fields**:
  - `dayKey`: Unique calendar-day key.
  - `endedFocusCount`: Count of focus sessions ended that day, including stopped-early sessions.
  - `endedBreakCount`: Count of break sessions ended that day, including stopped-early sessions.
  - `hydrationCount`: Count of hydration events for the day.
  - `movementCount`: Count of movement events for the day.
  - `lastHydrationAt`: Timestamp of the most recent hydration event, if any.
  - `hydrationTimerAnchorAt`: Timestamp from which the 60-minute hydration timer currently runs.
  - `hydrationReminderActive`: Whether the reminder should currently be shown while the app is open.
  - `updatedAt`: Timestamp of the most recent summary refresh.
- **Validation Rules**:
  - One summary exists per `dayKey`.
  - `hydrationTimerAnchorAt` is set to app-open time when no hydration has been logged that day.
  - Summary counts must match persisted `SessionRecord` and `WellnessEvent` rows for the same `dayKey`.

## Relationships

- One `DailyActivitySummary` aggregates many `SessionRecord` entries for the same `dayKey`.
- One `DailyActivitySummary` aggregates many `WellnessEvent` entries for the same `dayKey`.
- `WellnessEvent(type=hydration)` updates `DailyActivitySummary.lastHydrationAt`, `hydrationCount`, and `hydrationTimerAnchorAt`.
- `SessionRecord` updates `endedFocusCount` or `endedBreakCount` when a session reaches the `ended` state.

## State Transitions

### SessionRecord Lifecycle

1. `active` on session start.
2. `active -> paused` when the user pauses the timer.
3. `paused -> active` when the user resumes.
4. `active -> ended(completed)` when remaining time reaches zero.
5. `active -> ended(stopped)` when the user stops early.
6. `paused -> ended(stopped)` when the user stops while paused.

### DailyActivitySummary Reminder Lifecycle

1. On app open or daily rollover, set `hydrationTimerAnchorAt` to the app-open time if no hydration event exists for the new day.
2. When a hydration event is recorded, update `lastHydrationAt`, increment `hydrationCount`, reset `hydrationTimerAnchorAt` to the event time, and clear `hydrationReminderActive`.
3. While the app is open, mark `hydrationReminderActive` once 60 minutes have elapsed since `hydrationTimerAnchorAt`.
4. On daily rollover, reset counts and anchors for the new `dayKey` without deleting any in-progress session state that must still complete.

## Derived View Model Requirements

- The main screen requires a derived view model that combines the active `SessionRecord` and current `DailyActivitySummary`.
- The view model must expose the current screen state: `idle`, `focusActive`, `focusPaused`, `breakActive`, `breakPaused`, `focusCompletedPrompt`, or `error`.
- Remaining time must be computed from timestamps and the injected clock, not stored as a continuously decremented mutable field.
