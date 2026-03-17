# Quickstart: Pomogotchi Core Timer

## Prerequisites

- Flutter SDK matching the repository's configured stable toolchain
- Platform toolchains for Android or iOS development
- Access to the PowerSync Flutter package and its SQLite runtime
- For repository tests that instantiate PowerSync directly, the `powersync-sqlite-core` binary placed at the project root per the official unit-testing guide

## Setup

```bash
cd flutter_pomodoro
flutter pub get
flutter run
```

Version 1 runs PowerSync in local-only mode, so no backend connector or `connect()` flow is required during initial implementation.

## Automated Verification

```bash
dart format .
flutter analyze
flutter test
flutter test integration_test
```

## Manual Verification Flow

### User Story 1: Timer lifecycle

1. Launch the app and confirm the main screen opens in idle with `40:00`.
2. Start a focus session and verify the timer begins immediately.
3. Pause, resume, and stop a focus session; confirm time freezes on pause and the focus total increments when stopped.
4. Start a new focus session, let it complete, and confirm the completion prompt offers a 10-minute break.
5. Start the break, pause and resume it, then complete it and confirm the screen returns to idle.
6. Repeat with app background and resume during an active session; confirm the timer remains accurate.

### User Story 2: Wellness logging

1. Log a hydration event and confirm the hydration total increments immediately.
2. Log a movement event and confirm the movement total increments immediately.
3. Log both event types while a timer is active and confirm the timer continues uninterrupted.

### User Story 3: Reminders and prompts

1. Open the app with no hydration event logged for the day and confirm the 60-minute hydration timer begins from app open.
2. Keep the app open until the threshold is crossed and confirm the hydration reminder becomes visible.
3. Log hydration and confirm the reminder clears immediately and the reminder timer resets.
4. Confirm the app never shows an active timer and completed-session prompt at the same time.

## Implementation Notes

- Use an injectable clock in domain and application code so timer and reminder logic can be tested deterministically.
- Keep the countdown loop in memory and use PowerSync queries only for persisted state changes.
- Group multi-table persistence changes with `writeTransaction`.
- Profile timer drift and frame pacing before merge, especially around pause/resume and lifecycle changes.
- If a later release introduces sync, document connector setup, auth token retrieval, and status UI in this file at that time.
