import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pomogotchi/features/pomodoro/data/powersync_pomodoro_repository.dart';
import 'package:pomogotchi/features/pomodoro/data/schema/pomodoro_schema.dart';
import 'package:pomogotchi/features/pomodoro/domain/models/session_record.dart';
import 'package:pomogotchi/features/pomodoro/domain/models/wellness_event.dart';
import 'package:powersync/powersync.dart';

final _runPowerSyncDatabaseTests =
    Platform.environment['RUN_POWERSYNC_DB_TESTS'] == '1';
const _powerSyncDatabaseSkipReason =
    'Requires the PowerSync native test runtime. Set RUN_POWERSYNC_DB_TESTS=1 after installing libpowersync.dylib.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PowerSyncDatabase database;
  late PowerSyncPomodoroRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pomogotchi-repository');
    database = PowerSyncDatabase(
      schema: pomodoroSchema,
      path: p.join(tempDir.path, 'repository.db'),
    );
    await database.initialize();
    repository = PowerSyncPomodoroRepository(
      database,
      currentUserId: () => 'user-1',
    );
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  test(
    'creates authenticated daily summary ids per day',
    () async {
      final summary = await repository.loadOrCreateDailySummary(
        dayKey: '2026-01-01',
        openedAt: DateTime.utc(2026, 1, 1, 9),
      );

      expect(summary.id, 'user-1:2026-01-01');
      expect(summary.dayKey, '2026-01-01');
      expect(summary.endedFocusCount, 0);
      expect(summary.hydrationReminderActive, isFalse);
    },
    skip: _runPowerSyncDatabaseTests ? false : _powerSyncDatabaseSkipReason,
  );

  test(
    'tracks focus completion in the daily summary',
    () async {
      await repository.loadOrCreateDailySummary(
        dayKey: '2026-01-01',
        openedAt: DateTime.utc(2026, 1, 1, 9),
      );
      final session = await repository.createSession(
        type: SessionType.focus,
        startedAt: DateTime.utc(2026, 1, 1, 9),
        plannedDurationSeconds: 1500,
        dayKey: '2026-01-01',
      );

      final paused = await repository.pauseSession(
        sessionId: session.id,
        pausedAt: DateTime.utc(2026, 1, 1, 9, 10),
        remainingSecondsAtPause: 900,
      );
      expect(paused.state, SessionLifecycleState.paused);

      final resumed = await repository.resumeSession(
        sessionId: session.id,
        resumedAt: DateTime.utc(2026, 1, 1, 9, 12),
      );
      expect(resumed.state, SessionLifecycleState.active);

      final ended = await repository.endSession(
        sessionId: session.id,
        endedAt: DateTime.utc(2026, 1, 1, 9, 25),
        outcome: SessionOutcome.completed,
      );
      final summary = await repository.refreshDailySummary(
        dayKey: '2026-01-01',
        now: DateTime.utc(2026, 1, 1, 9, 25),
      );

      expect(ended.state, SessionLifecycleState.ended);
      expect(ended.outcome, SessionOutcome.completed);
      expect(summary.endedFocusCount, 1);
      expect(summary.endedBreakCount, 0);
    },
    skip: _runPowerSyncDatabaseTests ? false : _powerSyncDatabaseSkipReason,
  );

  test(
    'logs hydration events and resets reminder state in daily summary',
    () async {
      await repository.loadOrCreateDailySummary(
        dayKey: '2026-01-01',
        openedAt: DateTime.utc(2026, 1, 1, 9),
      );
      await repository.setHydrationReminderState(
        dayKey: '2026-01-01',
        anchorAt: DateTime.utc(2026, 1, 1, 10),
        isActive: true,
      );

      final event = await repository.addWellnessEvent(
        type: WellnessEventType.hydration,
        occurredAt: DateTime.utc(2026, 1, 1, 10, 15),
        dayKey: '2026-01-01',
      );
      final summary = await repository.refreshDailySummary(
        dayKey: '2026-01-01',
        now: DateTime.utc(2026, 1, 1, 10, 15),
      );

      expect(event.type, WellnessEventType.hydration);
      expect(summary.hydrationCount, 1);
      expect(summary.hydrationReminderActive, isFalse);
      expect(summary.lastHydrationAt, DateTime.utc(2026, 1, 1, 10, 15));
      expect(summary.hydrationTimerAnchorAt, DateTime.utc(2026, 1, 1, 10, 15));
    },
    skip: _runPowerSyncDatabaseTests ? false : _powerSyncDatabaseSkipReason,
  );

  test(
    'resets the current day back to an empty summary',
    () async {
      await repository.createSession(
        type: SessionType.focus,
        startedAt: DateTime.utc(2026, 1, 1, 9),
        plannedDurationSeconds: 1500,
        dayKey: '2026-01-01',
      );
      await repository.addWellnessEvent(
        type: WellnessEventType.movement,
        occurredAt: DateTime.utc(2026, 1, 1, 10),
        dayKey: '2026-01-01',
      );

      await repository.resetCurrentDay(
        dayKey: '2026-01-01',
        now: DateTime.utc(2026, 1, 1, 10, 30),
      );
      final activeSession = await repository.loadActiveSession();
      final summary = await repository.refreshDailySummary(
        dayKey: '2026-01-01',
        now: DateTime.utc(2026, 1, 1, 10, 30),
      );

      expect(activeSession, isNull);
      expect(summary.endedFocusCount, 0);
      expect(summary.movementCount, 0);
    },
    skip: _runPowerSyncDatabaseTests ? false : _powerSyncDatabaseSkipReason,
  );
}
