# Implementation Plan: Pomogotchi Core Timer

**Branch**: `[001-pomogotchi-timer]` | **Date**: 2026-03-16 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-pomogotchi-timer/spec.md` plus planning context: "Pomogotch is a Flutter app that uses PowerSync with local SQLite and should limit external dependencies."

## Summary

Build a local-first Flutter timer app with a single primary screen that runs fixed focus and break sessions, tracks hydration and movement events, and persists current-day state on-device. Based on official PowerSync guidance for pre-login apps, version 1 should use one local `PowerSyncDatabase` instance with local-only tables and no `connect()` call, while timer math and reminder rules stay in testable domain services above a thin repository boundary.

## Technical Context

**Language/Version**: Dart 3.11.x with Flutter stable  
**Primary Dependencies**: Flutter SDK widgets, `powersync` Flutter SDK, PowerSync SQLite runtime, cupertino_icons, `uuid` (stable v4 row-ID generation; the Dart SDK has no built-in UUID equivalent and `dart:math` random values are not suitable for persistent unique row IDs)
**Storage**: Local-only PowerSync-managed SQLite database for current-day sessions, wellness events, and summary snapshots  
**Testing**: `flutter_test` for unit and widget coverage, `integration_test` for timer lifecycle and resume flows  
**Target Platform**: Android and iOS for the feature release; macOS may be used for development verification; web is out of scope for this SQLite-backed feature slice  
**Project Type**: Flutter mobile application  
**Constraints**: No login, fixed 40/10 session lengths, hydration reminders only while the app is open, current-day local persistence only, PowerSync local-only tables in v1, no backend connector in v1, minimal external dependencies, accessible controls and states on the main screen  
**Scale/Scope**: Single local user per device, one primary screen, three persisted domain entities, current-day history only for version 1

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Research Gate

- **I. Quality Is a Product Requirement**: PASS. Timer calculations, reminder timing, and state transitions will live in domain services and controllers under `lib/features/pomodoro/` rather than in widget trees. Only the PowerSync/SQLite dependency set is added beyond the Flutter SDK, and PowerSync specifics remain isolated in the data layer.
- **II. UX Consistency Is Mandatory**: PASS. The feature is centered on a single shared app shell with explicit idle, active, completed, and error states, plus accessible labels for all primary actions.
- **III. Test the Behavior That Matters**: PASS. The plan includes unit tests for timer and reminder rules, widget tests for main-screen states, and integration tests for start/pause/resume/complete and lifecycle restore flows.
- **IV. Performance Must Be Measured**: PASS. The design uses timestamp-derived countdown math to avoid drift, keeps rebuild scope localized, and requires profiling timer accuracy and frame pacing before merge.
- **V. Technical Decisions Follow Product Value**: PASS. The design chooses Flutter core state primitives over heavier state libraries, uses PowerSync in local-only mode because the release has no login or backend scope, and introduces a repository seam only where it isolates persistence behavior.

## Project Structure

### Documentation (this feature)

```text
specs/001-pomogotchi-timer/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── local-data-boundary.md
│   └── main-screen-ui.md
└── tasks.md
```

### Source Code (flutter_pomodoro/)

```text
lib/
├── app/
│   ├── app.dart
│   └── theme/
├── features/
│   └── pomodoro/
│       ├── application/
│       ├── data/
│       ├── domain/
│       └── presentation/
├── shared/
│   ├── models/
│   ├── services/
│   └── widgets/
└── main.dart

test/
├── unit/
│   └── pomodoro/
└── widget/
    └── pomodoro/

integration_test/
└── pomodoro/

android/
ios/
macos/
web/
```

**Structure Decision**: Use a single Flutter application with feature-first organization under `lib/features/pomodoro/`. This keeps timer logic, PowerSync schema/query code, and the main-screen UI separated while preserving a simple repository layout and minimizing architectural overhead.

## Phase 0: Research

### Research Focus

- Confirm whether version 1 should use PowerSync in local-only mode or connected sync mode.
- Define how PowerSync client-side schemas, indexes, and local-only tables should map to the Pomogotchi entities.
- Define the query and transaction patterns for Flutter widgets and repositories.
- Establish timer accuracy and lifecycle handling rules that satisfy the spec's drift and restore requirements.
- Bound platform scope around the SQLite-backed persistence choice.
- Choose the minimum viable automated test strategy that satisfies the constitution and the PowerSync test runtime.

### Research Output

- [research.md](./research.md) records PowerSync-specific findings for SDK mode, schema design, query patterns, transaction use, status APIs, and test setup.

## Phase 1: Design & Contracts

### Planned Artifacts

- [data-model.md](./data-model.md) defines the session, wellness event, and daily summary entities, including validation rules and state transitions.
- [contracts/main-screen-ui.md](./contracts/main-screen-ui.md) defines the user-facing screen states, controls, semantics labels, and transition expectations.
- [contracts/local-data-boundary.md](./contracts/local-data-boundary.md) defines the repository contract between the app layer and the local-only PowerSync store, including query and transaction rules.
- [quickstart.md](./quickstart.md) captures implementation setup, verification commands, and manual QA scenarios for the MVP.

## Phase 2: Implementation Strategy

### Delivery Sequence

1. Establish the app shell, theme tokens, clock abstraction, and feature module structure.
2. Implement the domain layer for session state transitions, countdown math, hydration reminder timing, and daily rollovers.
3. Add the local-only PowerSync data layer: define schema tables and indexes, initialize one database instance, implement watch queries and transactions, and defer `connect()` plus backend connector work until sync scope exists.
4. Build the main timer screen with accessible controls, explicit idle/active/completed/error states, and one-tap hydration and movement logging.
5. Add widget and integration coverage for the primary flows, then verify timer drift, lifecycle restore, and reminder timing on target devices.

### Story Mapping

- **User Story 1**: Timer lifecycle, completion CTA, pause/resume/stop behavior, active session restore.
- **User Story 2**: Hydration and movement logging, daily summary rendering, one-tap updates.
- **User Story 3**: Hydration reminder visibility, completed-session indicators, idle reminder rules.

## Post-Design Constitution Check

- **I. Quality Is a Product Requirement**: PASS. The plan isolates domain logic, data access, and UI contracts, and avoids speculative layers beyond the repository seam needed for local-only PowerSync usage.
- **II. UX Consistency Is Mandatory**: PASS. The UI contract defines state-specific behavior, accessibility labels, and shared screen structure before implementation starts.
- **III. Test the Behavior That Matters**: PASS. Research and quickstart artifacts lock in unit, widget, and integration expectations for the timer lifecycle and reminder flows.
- **IV. Performance Must Be Measured**: PASS. The design artifacts require timestamp-based countdowns, lifecycle restore checks, and timer-drift verification before merge.
- **V. Technical Decisions Follow Product Value**: PASS. The chosen stack uses Flutter primitives and the minimum PowerSync feature set needed for the product today, while deferring backend sync concerns until the product actually requires them.

## Complexity Tracking

No constitution exceptions or additional complexity justifications are required at planning time.
