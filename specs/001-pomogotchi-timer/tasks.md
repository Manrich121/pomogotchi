# Tasks: Pomogotchi Core Timer

**Input**: Design documents from `/specs/001-pomogotchi-timer/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Automated tests are required by the project constitution for business logic, reusable UI behavior, and critical timer lifecycle journeys.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Update dependencies for PowerSync local-only storage, integration testing, and UUID generation in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/pubspec.yaml
- [ ] T002 Create the feature-first directory structure for app, pomodoro, and test modules under /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib, /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/test, and /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/integration_test
- [ ] T003 [P] Replace the default app bootstrap with Pomogotchi app wiring in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/main.dart and /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/app/app.dart
- [ ] T004 [P] Add shared theme tokens and Material theme setup in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/app/theme/app_theme.dart

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T005 Define the local-only PowerSync schema and indexes in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/data/schema/pomodoro_schema.dart
- [ ] T006 [P] Create the single-database PowerSync bootstrap and ownership service in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/data/pomodoro_database.dart
- [ ] T007 [P] Create the session, wellness event, and daily summary domain models in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/domain/models/session_record.dart, /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/domain/models/wellness_event.dart, and /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/domain/models/daily_activity_summary.dart
- [ ] T008 [P] Create the repository interface and typed persistence failures in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/application/pomodoro_repository.dart and /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/application/pomodoro_failure.dart
- [ ] T009 [P] Create PowerSync row mappers and repository scaffolding in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/data/powersync_pomodoro_repository.dart
- [ ] T010 [P] Create the injectable clock and app lifecycle services in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/shared/services/app_clock.dart and /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/shared/services/app_lifecycle_service.dart
- [ ] T011 Create the shared pomodoro screen scaffold and extend the app bootstrap created in T003 with route wiring in /Users/manrichvangreunen/Documents/my-projects/flutter_pomodoro/lib/features/pomodoro/presentation/screens/pomodoro_screen.dart and /Users/manrichvangreunen/Documents/my-projects/flutter_pomodoro/lib/app/app.dart
- [ ] T012 Create the base controller and view-state model covering all nine states from FR-004 (loading, idle, focus active, focus paused, break active, break paused, focus completed, break completed, error) in /Users/manrichvangreunen/Documents/my-projects/flutter_pomodoro/lib/features/pomodoro/application/pomodoro_controller.dart and /Users/manrichvangreunen/Documents/my-projects/flutter_pomodoro/lib/features/pomodoro/application/pomodoro_view_state.dart

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Run a Pomodoro Cycle (Priority: P1) 🎯 MVP

**Goal**: Deliver a working 40-minute focus timer with pause, resume, stop, completion prompt, break start, and active-session restore.

**Independent Test**: Start a focus session from idle, pause and resume it, complete it, start the prompted break, and verify the timer restores accurately after app resume.

### Tests for User Story 1

- [ ] T013 [P] [US1] Add unit tests for session state transitions and countdown math in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/test/unit/pomodoro/session_engine_test.dart
- [ ] T014 [P] [US1] Add widget tests for idle, running, paused, completed, and break-completed timer states; include golden tests for at least the idle and focus-active states to protect against visual regressions in /Users/manrichvangreunen/Documents/my-projects/flutter_pomodoro/test/widget/pomodoro/pomodoro_timer_flow_test.dart
- [ ] T015 [P] [US1] Add an integration test for focus-to-break lifecycle, app resume restore, and daily-totals persistence across close/reopen (FR-014) in /Users/manrichvangreunen/Documents/my-projects/flutter_pomodoro/integration_test/pomodoro/timer_lifecycle_test.dart

### Implementation for User Story 1

- [ ] T016 [P] [US1] Implement the session engine for focus, break, pause, resume, stop, and completion rules in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/domain/services/session_engine.dart
- [ ] T017 [P] [US1] Implement active-session queries and mutations in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/data/powersync_pomodoro_repository.dart
- [ ] T018 [US1] Implement start, pause, resume, stop, break-start, and restore flows in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/application/pomodoro_controller.dart
- [ ] T019 [P] [US1] Build the timer header and session action bar widgets in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/presentation/widgets/timer_header.dart and /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/presentation/widgets/session_action_bar.dart
- [ ] T020 [US1] Add the focus completion prompt and break-completed transition indicator, wire the full timer flow including loading and break-completed states into the main screen in /Users/manrichvangreunen/Documents/my-projects/flutter_pomodoro/lib/features/pomodoro/presentation/widgets/completion_prompt.dart and /Users/manrichvangreunen/Documents/my-projects/flutter_pomodoro/lib/features/pomodoro/presentation/screens/pomodoro_screen.dart

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - Log Wellness Events (Priority: P2)

**Goal**: Allow one-tap hydration and movement logging with live daily summary updates that do not interrupt timer behavior.

**Independent Test**: Log hydration and movement events from the main screen and verify the daily totals update immediately while an active timer keeps running.

### Tests for User Story 2

- [ ] T021 [P] [US2] Add unit tests for daily summary aggregation (explicitly covering stopped-early sessions incrementing the same counter as completed sessions per FR-011) and wellness write behavior in /Users/manrichvangreunen/Documents/my-projects/flutter_pomodoro/test/unit/pomodoro/daily_summary_service_test.dart
- [ ] T022 [P] [US2] Add widget tests for hydration and movement logging updates in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/test/widget/pomodoro/wellness_logging_test.dart

### Implementation for User Story 2

- [ ] T023 [P] [US2] Implement the daily summary aggregation service in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/domain/services/daily_summary_service.dart
- [ ] T024 [P] [US2] Implement wellness-event writes and summary transactions in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/data/powersync_pomodoro_repository.dart
- [ ] T025 [US2] Extend the controller with hydration and movement logging actions in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/application/pomodoro_controller.dart
- [ ] T026 [P] [US2] Build the daily summary panel and wellness action widgets in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/presentation/widgets/daily_summary_panel.dart and /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/presentation/widgets/wellness_actions.dart
- [ ] T027 [US2] Integrate live summary data and one-tap wellness logging into /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/presentation/screens/pomodoro_screen.dart

**Checkpoint**: At this point, User Stories 1 and 2 should both work independently

---

## Phase 5: User Story 3 - Receive Contextual Prompts (Priority: P3)

**Goal**: Show hydration reminders, suppress false completion prompts for stopped sessions, and surface safe recovery UI when persisted state fails.

**Independent Test**: Keep the app open until the hydration threshold is reached, confirm the reminder appears and clears after hydration, and verify stopped-early sessions return to idle without showing a completed-session prompt.

### Tests for User Story 3

- [ ] T028 [P] [US3] Add unit tests for hydration reminder timing and day rollover rules in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/test/unit/pomodoro/hydration_reminder_service_test.dart
- [ ] T029 [P] [US3] Add widget tests for reminder visibility, completed-prompt suppression, and error states in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/test/widget/pomodoro/contextual_prompts_test.dart
- [ ] T030 [P] [US3] Add an integration test for idle reminder visibility, clear-on-hydration behavior, and day-rollover resetting daily counts without disrupting an in-progress timer (EC-003) in /Users/manrichvangreunen/Documents/my-projects/flutter_pomodoro/integration_test/pomodoro/hydration_reminder_flow_test.dart

### Implementation for User Story 3

- [ ] T031 [P] [US3] Implement the hydration reminder service and day rollover rules in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/domain/services/hydration_reminder_service.dart
- [ ] T032 [P] [US3] Implement reminder refresh, app-open anchoring, and recovery reads in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/data/powersync_pomodoro_repository.dart
- [ ] T033 [US3] Extend the controller with reminder evaluation, stopped-early prompt suppression, and error recovery in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/application/pomodoro_controller.dart
- [ ] T034 [P] [US3] Build the hydration reminder banner and error-state widgets in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/presentation/widgets/hydration_reminder_banner.dart and /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/presentation/widgets/pomodoro_error_state.dart
- [ ] T035 [US3] Integrate reminder, retry, and day-rollover refresh handling into /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/presentation/screens/pomodoro_screen.dart

**Checkpoint**: All user stories should now be independently functional

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T036 [P] Add accessibility labels and focus-order refinements in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/presentation/widgets/timer_header.dart, /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/presentation/widgets/session_action_bar.dart, /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/presentation/widgets/wellness_actions.dart, and /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/presentation/widgets/hydration_reminder_banner.dart
- [ ] T037 Optimize timer rebuild scope and watch-query subscriptions in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/application/pomodoro_controller.dart and /Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomodoro/lib/features/pomodoro/presentation/screens/pomodoro_screen.dart
- [ ] T038 [P] Update setup and verification documentation in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/README.md and /Users/manrichvangreunen/Documents/my-projects/pomogotchi/specs/001-pomogotchi-timer/quickstart.md
- [ ] T039 Run `dart format .`, `flutter analyze`, `flutter test`, and `flutter test integration_test/` (requires a connected device or emulator for integration tests), then confirm no login prompt or custom-session controls are present in the UI (FR-015, FR-016), and record all verification results in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/specs/001-pomogotchi-timer/quickstart.md
- [ ] T040 [P] Profile timer accuracy and frame pacing on a target Android or iOS device; record drift measurements against SC-002 and any frame-drop observations in /Users/manrichvangreunen/Documents/my-projects/pomogotchi/specs/001-pomogotchi-timer/quickstart.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - blocks all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational completion
- **User Story 2 (Phase 4)**: Depends on Foundational completion and reuses the shared screen scaffold from T011 and controller base from T012
- **User Story 3 (Phase 5)**: Depends on Foundational completion and reuses the shared screen scaffold from T011 and controller base from T012
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational completion and is the recommended MVP slice
- **User Story 2 (P2)**: Can start after Foundational completion; it reuses the shared screen and controller shell but remains independently testable once its own data and UI tasks are complete
- **User Story 3 (P3)**: Can start after Foundational completion; it reuses the shared screen and controller shell but remains independently testable once its own reminder and UI tasks are complete

### Within Each User Story

- Tests MUST be written before or alongside implementation for timer logic, widget behavior, and lifecycle journeys
- Domain services before controller wiring
- Repository mutations and queries before final UI integration
- Story-specific widgets before final screen composition

### Parallel Opportunities

- T003 and T004 can run in parallel after T001 and T002
- T006 through T010 can run in parallel once T005 is defined
- Within US1, T013, T014, T015, T016, T017, and T019 can run in parallel where team capacity exists
- Within US2, T021, T022, T023, T024, and T026 can run in parallel once foundational interfaces are in place
- Within US3, T028, T029, T030, T031, T032, and T034 can run in parallel once foundational interfaces are in place
- T036, T038, and T040 can run in parallel after all story work is complete

---

## Parallel Example: User Story 1

```bash
# Launch the US1 test work together:
Task: "Add unit tests for session state transitions and countdown math in test/unit/pomodoro/session_engine_test.dart"
Task: "Add widget tests for idle, running, paused, and completed timer states in test/widget/pomodoro/pomodoro_timer_flow_test.dart"
Task: "Add an integration test for focus-to-break lifecycle and app resume restore in integration_test/pomodoro/timer_lifecycle_test.dart"

# Launch the US1 implementation work that touches separate files:
Task: "Implement the session engine in lib/features/pomodoro/domain/services/session_engine.dart"
Task: "Implement active-session queries and mutations in lib/features/pomodoro/data/powersync_pomodoro_repository.dart"
Task: "Build the timer header and session action bar widgets in lib/features/pomodoro/presentation/widgets/timer_header.dart and lib/features/pomodoro/presentation/widgets/session_action_bar.dart"
```

---

## Parallel Example: User Story 2

```bash
# Launch the US2 test and domain work together:
Task: "Add unit tests for daily summary aggregation and wellness write behavior in test/unit/pomodoro/daily_summary_service_test.dart"
Task: "Add widget tests for hydration and movement logging updates in test/widget/pomodoro/wellness_logging_test.dart"
Task: "Implement the daily summary aggregation service in lib/features/pomodoro/domain/services/daily_summary_service.dart"

# Launch the US2 data and widget work together:
Task: "Implement wellness-event writes and summary transactions in lib/features/pomodoro/data/powersync_pomodoro_repository.dart"
Task: "Build the daily summary panel and wellness action widgets in lib/features/pomodoro/presentation/widgets/daily_summary_panel.dart and lib/features/pomodoro/presentation/widgets/wellness_actions.dart"
```

---

## Parallel Example: User Story 3

```bash
# Launch the US3 test work together:
Task: "Add unit tests for hydration reminder timing and day rollover rules in test/unit/pomodoro/hydration_reminder_service_test.dart"
Task: "Add widget tests for reminder visibility, completed-prompt suppression, and error states in test/widget/pomodoro/contextual_prompts_test.dart"
Task: "Add an integration test for idle reminder visibility and clear-on-hydration behavior in integration_test/pomodoro/hydration_reminder_flow_test.dart"

# Launch the US3 implementation work that touches separate files:
Task: "Implement the hydration reminder service in lib/features/pomodoro/domain/services/hydration_reminder_service.dart"
Task: "Implement reminder refresh, app-open anchoring, and recovery reads in lib/features/pomodoro/data/powersync_pomodoro_repository.dart"
Task: "Build the hydration reminder banner and error-state widgets in lib/features/pomodoro/presentation/widgets/hydration_reminder_banner.dart and lib/features/pomodoro/presentation/widgets/pomodoro_error_state.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1
4. Validate the timer lifecycle with widget and integration coverage before expanding scope

### Incremental Delivery

1. Finish Setup and Foundational work to stabilize the PowerSync local-only foundation
2. Deliver User Story 1 as the first demoable slice
3. Add User Story 2 for wellness logging and current-day summaries
4. Add User Story 3 for reminders, recovery behavior, and contextual prompts
5. Finish with polish, accessibility, and full verification

### Parallel Team Strategy

1. Complete Setup and Foundational work together
2. After Phase 2, assign one developer to the timer flow, one to wellness logging, and one to reminders/prompts
3. Merge each story only after its own tests and independent manual checks pass

---

## Notes

- All tasks use the required checklist format with task IDs, optional `[P]` markers, optional `[US#]` labels, and exact file paths
- User Story 1 is the recommended MVP scope
- The PowerSync work assumes local-only tables and no `connect()` call in version 1
- Keep timer countdown logic in memory and persist only state transitions, summary updates, and wellness events
