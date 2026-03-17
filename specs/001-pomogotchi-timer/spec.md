# Feature Specification: Pomogotchi Core Timer

**Feature Branch**: `[001-pomogotchi-timer]`  
**Created**: 2026-03-16  
**Status**: Draft  
**Input**: User description: "Develop Pomogothci, a pomodoro timer app for fixed focus and break sessions with hydration and movement tracking."

## Clarifications

### Session 2026-03-16

- Q: When should the hydration reminder be active? → A: Show hydration reminders anytime the app is open, including idle.
- Q: Should stopped-early sessions count in daily totals? → A: Count stopped-early sessions the same as completed sessions.
- Q: When does the daily 60-minute hydration timer start? → A: Start counting from app open or the last hydration event, whichever is later.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run a Pomodoro Cycle (Priority: P1)

As a user trying to focus, I want to start a fixed 40-minute focus session, manage it while it runs, and be prompted into a fixed 10-minute break when focus time is complete.

**Why this priority**: The timer is the core product behavior. Without a reliable focus-to-break flow, the app does not deliver its main purpose.

**Independent Test**: Can be fully tested by starting a focus session from idle, pausing and resuming it, then completing it and starting the prompted break.

**Acceptance Scenarios**:

1. **Given** the app is idle on the main timer screen, **When** the user taps the primary start control, **Then** a 40-minute focus session begins counting down and the current state is shown as focus.
2. **Given** a focus session is running, **When** the user pauses it, **Then** the countdown stops and the user can resume or stop the session without losing the remaining time.
3. **Given** a focus session reaches zero, **When** the countdown completes, **Then** the app shows a completion indicator and a clear call to action to begin a 10-minute break.
4. **Given** the user starts the prompted break, **When** the 10-minute break reaches zero, **Then** the app marks the break complete and returns to a ready state for the next focus session.

---

### User Story 2 - Log Wellness Events (Priority: P2)

As a user building healthy work habits, I want to log hydration and movement or stretch events in one tap so I can see how often I am caring for myself during the day.

**Why this priority**: The wellness tracking adds the behavior change value that differentiates the app from a basic timer.

**Independent Test**: Can be fully tested by logging water and movement events from the main screen and confirming that visible totals update immediately without interrupting the timer.

**Acceptance Scenarios**:

1. **Given** the main screen is visible, **When** the user logs a hydration event, **Then** the hydration total increases by one and the app updates the last hydration time used for reminders.
2. **Given** the main screen is visible, **When** the user logs a movement or stretch event, **Then** the movement total increases by one and the updated count is visible immediately.
3. **Given** a focus or break session is active, **When** the user logs a wellness event, **Then** the timer continues uninterrupted while the count is recorded.

---

### User Story 3 - Receive Contextual Prompts (Priority: P3)

As a user who may lose track of my habits, I want the app to surface timely reminders and status indicators so I know when to drink water and when a session is complete.

**Why this priority**: Reminders and completion feedback reinforce the habit loop, but they depend on the timer and logging behaviors already existing.

**Independent Test**: Can be fully tested by allowing a session to complete and by simulating the no-hydration threshold to confirm that prompts appear and clear at the right times.

**Acceptance Scenarios**:

1. **Given** the app is open and no hydration event has been logged for the reminder interval, **When** the threshold is reached, **Then** the app displays a visible reminder to drink water even if no focus or break session is active.
2. **Given** a hydration reminder is visible, **When** the user logs a hydration event, **Then** the reminder clears immediately.
3. **Given** the user stops a focus or break session before it completes, **When** the session ends early, **Then** the app returns to idle without showing the completed-session prompt for that session.

### Edge Cases

- If the user leaves the app or locks the device during an active focus or break session, the remaining time must still be correct when they return.
- If the user pauses a session with less than one minute remaining, resuming must continue from the paused time rather than restarting the session.
- If a day changes while the app is open, daily wellness and session counts must reset for the new day without erasing an in-progress timer.
- If the user opens the app after more than 60 minutes have passed since midnight and has not logged hydration yet, the hydration reminder timer must begin from app open rather than showing an immediate overdue reminder.
- If the user logs a hydration event exactly when a hydration reminder becomes due, the app must avoid showing a stale reminder after the event is recorded.
- If the app cannot restore retained session or activity data on launch, the user must see a full-screen error message stating that data could not be loaded and offering a single retry or dismiss action; no timer controls must be shown while the error is visible, and dismissing must leave the app in a safe idle state.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST open to a single main screen that shows the remaining session time prominently and presents a large primary control for starting or stopping the current session; all tappable controls on the main screen MUST meet a minimum touch target of 44 × 44 pt (iOS) or 48 × 48 dp (Android).
- **FR-002**: The system MUST allow the user to start a fixed 40-minute focus session from the idle state with one primary action.
- **FR-003**: The system MUST allow the user to pause, resume, and stop an active focus session before completion.
- **FR-004**: The system MUST show the current session state as one of loading, idle, focus active, focus paused, break active, break paused, focus completed, break completed, or error. The loading state is displayed during app initialisation before the local database is ready. The break completed state is a transient indicator shown after a break session reaches zero; it requires no user action and automatically transitions to idle.
- **FR-005**: When a focus session completes, the system MUST show a full-screen or prominent overlay with a session completion message and a single primary call to action to begin the fixed 10-minute break.
- **FR-006**: The system MUST allow the user to start, pause, resume, and stop the fixed 10-minute break session after a focus session or from a completed-focus prompt.
- **FR-007**: When a break session completes, the system MUST transition to the break completed state, then automatically return to idle for the next focus session, and record the break in the daily totals; no user action is required to exit the break completed state.
- **FR-008**: The system MUST retain the active session state and remaining time on the same device so that an in-progress session can be resumed accurately after the user leaves and reopens the app.
- **FR-009**: The system MUST allow the user to log a hydration event with a single tap from the main screen.
- **FR-010**: The system MUST allow the user to log a movement or stretch event with a single tap from the main screen.
- **FR-011**: The system MUST display the current day's totals for ended focus sessions, ended break sessions, hydration events, and movement or stretch events. An ended session is any focus or break session that has stopped, whether it ran to completion or was stopped early; both types MUST increment the same daily counter.
- **FR-012**: The system MUST use a fixed 60-minute hydration reminder threshold and show a reminder whenever that threshold is reached while the app is open, including idle. On each day, the reminder countdown begins from the time the app is opened or the time of the most recent hydration event, whichever is later.
- **FR-013**: The system MUST clear any visible hydration reminder as soon as a hydration event is logged.
- **FR-014**: The system MUST retain the current day's activity totals on the same device when the app is closed and reopened.
- **FR-015**: The system MUST require no user login or account creation for this release.
- **FR-016**: The system MUST not offer custom session lengths, custom break durations, or custom break types in this release.
- **FR-017**: The system MUST provide accessible labels for timer status, primary actions, hydration logging, and movement logging, and all tappable controls MUST be usable with standard mobile accessibility tools.
- **FR-018**: The main screen MUST implement every state listed in FR-004—loading, idle, focus active, focus paused, break active, break paused, focus completed, break completed, and error—so the user always understands the current timer and reminder status.

### Key Entities *(include if feature involves data)*

- **Session**: A timed focus or break activity with a type, planned duration, current state, start time, remaining time, and completion outcome.
- **Wellness Event**: A hydration or movement log with an event type, recorded time, and the day it contributes to.
- **Daily Activity Summary**: The current day's totals for ended focus sessions, ended breaks, hydration events, movement events, the last hydration time, and whether a hydration reminder is active.

### Assumptions

- This release supports one local user per device, with no account system, cross-device syncing, or shared history.
- Daily totals are scoped to the current calendar day and reset automatically when a new day begins.
- The hydration reminder threshold is fixed at 60 minutes for version 1, is not user-configurable, and is evaluated whenever the app is open.
- If no hydration event has been logged yet for the day, the first hydration reminder countdown begins when the user opens the app.
- Session and activity history only need to be retained for the current day in version 1.
- Reminder and completion indicators are visual only for this initial release; sound, vibration, and notification-center behaviors are out of scope.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The app MUST reach an interactive main timer screen within 3 seconds of cold launch on a mid-range Android or iOS target device, verified by T040 profiling. The primary start control MUST be the most prominent interactive element on the main screen and reachable in no more than one tap from the initial screen.
- **SC-002**: During a complete 40-minute focus session and 10-minute break cycle, the timer display stays within 1 second of the expected remaining time at every user-visible checkpoint, including after leaving and reopening the app.
- **SC-003**: 100% of completed focus sessions present a completion indicator and break call to action within 2 seconds of the timer reaching zero.
- **SC-004**: In at least 95% of attempts, users can record a hydration or movement event in one tap and see the updated daily total within 1 second.
- **SC-005**: When no hydration event is recorded for 60 minutes, the water reminder is visible by minute 61 in 100% of qualifying cases whenever the app is open, including idle, and clears within 1 second after hydration is logged.
- **SC-006**: 100% of primary interactive controls on the main screen expose descriptive labels that can be identified by standard mobile accessibility tooling.
