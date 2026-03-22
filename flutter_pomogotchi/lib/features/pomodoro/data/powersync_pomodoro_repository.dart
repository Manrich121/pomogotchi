import 'package:pomogotchi/features/pomodoro/application/pomodoro_failure.dart';
import 'package:pomogotchi/features/pomodoro/application/pomodoro_repository.dart';
import 'package:pomogotchi/features/pomodoro/data/schema/pomodoro_schema.dart';
import 'package:pomogotchi/features/pomodoro/data/pomodoro_sync.dart';
import 'package:pomogotchi/features/pomodoro/domain/models/daily_activity_summary.dart';
import 'package:pomogotchi/features/pomodoro/domain/models/session_record.dart';
import 'package:pomogotchi/features/pomodoro/domain/models/wellness_event.dart';
import 'package:pomogotchi/features/pomodoro/domain/services/daily_summary_service.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

class PowerSyncPomodoroRepository implements PomodoroRepository {
  PowerSyncPomodoroRepository(
    this._database, {
    Uuid? uuid,
    String? Function()? currentUserId,
    DailySummaryService? dailySummaryService,
  }) : _uuid = uuid ?? const Uuid(),
       _currentUserId = currentUserId ?? currentPomodoroUserId,
       _dailySummaryService =
           dailySummaryService ?? const DailySummaryService();

  final PowerSyncDatabase _database;
  final Uuid _uuid;
  final String? Function() _currentUserId;
  final DailySummaryService _dailySummaryService;

  @override
  Future<SessionRecord?> loadActiveSession() async {
    try {
      final row = await _database.getOptional('''
        SELECT * FROM $sessionsTable
        WHERE state IN ('active', 'paused')
        ORDER BY started_at DESC
        LIMIT 1
        ''');
      if (row == null) {
        return null;
      }
      return _sessionFromRow(row);
    } catch (error, stackTrace) {
      throw PomodoroPersistenceFailure(
        'Failed to load active session',
        error,
        stackTrace,
      );
    }
  }

  @override
  Stream<SessionRecord?> watchActiveSession() {
    return _database
        .watch('''
          SELECT * FROM $sessionsTable
          WHERE state IN ('active', 'paused')
          ORDER BY started_at DESC
          LIMIT 1
          ''')
        .map((rows) => rows.isEmpty ? null : _sessionFromRow(rows.first));
  }

  @override
  Future<SessionRecord> createSession({
    required SessionType type,
    required DateTime startedAt,
    required int plannedDurationSeconds,
    required String dayKey,
  }) async {
    final id = _uuid.v4();
    final iso = startedAt.toUtc().toIso8601String();

    try {
      await _database.writeTransaction((tx) async {
        await tx.execute(
          '''
          UPDATE $sessionsTable
          SET state = 'ended', outcome = 'stopped', ended_at = ?, paused_at = NULL
          WHERE state IN ('active', 'paused')
          ''',
          [iso],
        );

        await tx.execute(
          '''
          INSERT INTO $sessionsTable (
            id, day_key, type, planned_duration_seconds, state, outcome,
            started_at, last_resumed_at, paused_at, ended_at, remaining_seconds_at_pause
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            id,
            dayKey,
            _sessionTypeToSql(type),
            plannedDurationSeconds,
            'active',
            null,
            iso,
            iso,
            null,
            null,
            null,
          ],
        );
      });
      final row = await _database.get(
        'SELECT * FROM $sessionsTable WHERE id = ?',
        [id],
      );
      return _sessionFromRow(row);
    } catch (error, stackTrace) {
      throw PomodoroPersistenceFailure(
        'Failed to create session',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<SessionRecord> pauseSession({
    required String sessionId,
    required DateTime pausedAt,
    required int remainingSecondsAtPause,
  }) async {
    try {
      await _database.execute(
        '''
        UPDATE $sessionsTable
        SET state = 'paused', paused_at = ?, remaining_seconds_at_pause = ?
        WHERE id = ?
        ''',
        [
          pausedAt.toUtc().toIso8601String(),
          remainingSecondsAtPause,
          sessionId,
        ],
      );

      final row = await _database.get(
        'SELECT * FROM $sessionsTable WHERE id = ?',
        [sessionId],
      );
      return _sessionFromRow(row);
    } catch (error, stackTrace) {
      throw PomodoroPersistenceFailure(
        'Failed to pause session',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<SessionRecord> resumeSession({
    required String sessionId,
    required DateTime resumedAt,
  }) async {
    try {
      await _database.execute(
        '''
        UPDATE $sessionsTable
        SET state = 'active', last_resumed_at = ?, paused_at = NULL
        WHERE id = ?
        ''',
        [resumedAt.toUtc().toIso8601String(), sessionId],
      );
      final row = await _database.get(
        'SELECT * FROM $sessionsTable WHERE id = ?',
        [sessionId],
      );
      return _sessionFromRow(row);
    } catch (error, stackTrace) {
      throw PomodoroPersistenceFailure(
        'Failed to resume session',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<SessionRecord> endSession({
    required String sessionId,
    required DateTime endedAt,
    required SessionOutcome outcome,
  }) async {
    try {
      final existingRow = await _database.get(
        'SELECT * FROM $sessionsTable WHERE id = ?',
        [sessionId],
      );
      final existingSession = _sessionFromRow(existingRow);
      if (existingSession.state == SessionLifecycleState.ended) {
        return existingSession;
      }

      final summary = await loadOrCreateDailySummary(
        dayKey: existingSession.dayKey,
        openedAt: endedAt,
      );
      final endedSession = existingSession.copyWith(
        state: SessionLifecycleState.ended,
        outcome: outcome,
        endedAt: endedAt.toUtc(),
      );
      final nextSummary = _dailySummaryService.applyEndedSession(
        summary: summary,
        session: endedSession,
        endedAt: endedAt,
      );

      await _database.writeTransaction((tx) async {
        await tx.execute(
          '''
          UPDATE $sessionsTable
          SET state = 'ended', outcome = ?, ended_at = ?, paused_at = NULL
          WHERE id = ?
          ''',
          [
            _sessionOutcomeToSql(outcome),
            endedAt.toUtc().toIso8601String(),
            sessionId,
          ],
        );
        await _writeDailySummary(tx, nextSummary);
      });

      final row = await _database.get(
        'SELECT * FROM $sessionsTable WHERE id = ?',
        [sessionId],
      );
      return _sessionFromRow(row);
    } catch (error, stackTrace) {
      throw PomodoroPersistenceFailure(
        'Failed to end session',
        error,
        stackTrace,
      );
    }
  }

  @override
  Stream<List<SessionRecord>> watchTodaySessions(String dayKey) {
    return _database
        .watch(
          '''
          SELECT * FROM $sessionsTable
          WHERE day_key = ?
          ORDER BY started_at DESC
          ''',
          parameters: [dayKey],
        )
        .map((rows) => rows.map(_sessionFromRow).toList(growable: false));
  }

  @override
  Future<WellnessEvent> addWellnessEvent({
    required WellnessEventType type,
    required DateTime occurredAt,
    required String dayKey,
  }) async {
    final id = _uuid.v4();
    try {
      final event = WellnessEvent(
        id: id,
        dayKey: dayKey,
        type: type,
        occurredAt: occurredAt.toUtc(),
      );
      final summary = await loadOrCreateDailySummary(
        dayKey: dayKey,
        openedAt: occurredAt,
      );
      final nextSummary = _dailySummaryService.applyWellnessEvent(
        summary: summary,
        event: event,
      );

      await _database.writeTransaction((tx) async {
        await tx.execute(
          '''
          INSERT INTO $wellnessEventsTable (id, day_key, type, occurred_at)
          VALUES (?, ?, ?, ?)
          ''',
          [
            id,
            dayKey,
            _wellnessTypeToSql(type),
            occurredAt.toUtc().toIso8601String(),
          ],
        );
        await _writeDailySummary(tx, nextSummary);
      });

      final row = await _database.get(
        'SELECT * FROM $wellnessEventsTable WHERE id = ?',
        [id],
      );
      return _wellnessFromRow(row);
    } catch (error, stackTrace) {
      throw PomodoroPersistenceFailure(
        'Failed to add wellness event',
        error,
        stackTrace,
      );
    }
  }

  @override
  Stream<List<WellnessEvent>> watchTodayWellnessEvents(String dayKey) {
    return _database
        .watch(
          '''
          SELECT * FROM $wellnessEventsTable
          WHERE day_key = ?
          ORDER BY occurred_at DESC
          ''',
          parameters: [dayKey],
        )
        .map((rows) => rows.map(_wellnessFromRow).toList(growable: false));
  }

  @override
  Future<DailyActivitySummary> loadOrCreateDailySummary({
    required String dayKey,
    required DateTime openedAt,
  }) async {
    try {
      final existing = await _database.getOptional(
        'SELECT * FROM $dailyActivitySummaryTable WHERE day_key = ? LIMIT 1',
        [dayKey],
      );
      if (existing != null) {
        return _dailySummaryFromRow(existing);
      }

      final created = _dailySummaryService.create(
        id: _dailySummaryId(dayKey),
        dayKey: dayKey,
        openedAt: openedAt,
      );
      await _database.execute(
        '''
        INSERT INTO $dailyActivitySummaryTable (
          id, day_key, ended_focus_count, ended_break_count, hydration_count,
          movement_count, last_hydration_at, hydration_timer_anchor_at,
          hydration_reminder_active, updated_at
        ) VALUES (?, ?, 0, 0, 0, 0, NULL, ?, 0, ?)
        ''',
        [
          created.id,
          created.dayKey,
          created.hydrationTimerAnchorAt.toIso8601String(),
          created.updatedAt.toIso8601String(),
        ],
      );
      return created;
    } catch (error, stackTrace) {
      throw PomodoroPersistenceFailure(
        'Failed to load or create daily summary',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<DailyActivitySummary> refreshDailySummary({
    required String dayKey,
    required DateTime now,
  }) async {
    try {
      final existingSummary = await loadOrCreateDailySummary(
        dayKey: dayKey,
        openedAt: now,
      );
      final sessionRows = await _database.getAll(
        'SELECT * FROM $sessionsTable WHERE day_key = ?',
        [dayKey],
      );
      final eventRows = await _database.getAll(
        'SELECT * FROM $wellnessEventsTable WHERE day_key = ?',
        [dayKey],
      );
      final refreshedSummary = _dailySummaryService.aggregate(
        summary: existingSummary,
        sessions: sessionRows.map(_sessionFromRow),
        wellnessEvents: eventRows.map(_wellnessFromRow),
        now: now,
      );
      await _writeDailySummary(_database, refreshedSummary);
      return refreshedSummary;
    } catch (error, stackTrace) {
      throw PomodoroPersistenceFailure(
        'Failed to refresh daily summary',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<DailyActivitySummary> setHydrationReminderState({
    required String dayKey,
    required DateTime anchorAt,
    required bool isActive,
  }) async {
    try {
      await loadOrCreateDailySummary(dayKey: dayKey, openedAt: anchorAt);
      await _database.execute(
        '''
        UPDATE $dailyActivitySummaryTable
        SET hydration_timer_anchor_at = ?, hydration_reminder_active = ?, updated_at = ?
        WHERE day_key = ?
        ''',
        [
          anchorAt.toUtc().toIso8601String(),
          isActive ? 1 : 0,
          anchorAt.toUtc().toIso8601String(),
          dayKey,
        ],
      );
      final row = await _database.get(
        'SELECT * FROM $dailyActivitySummaryTable WHERE day_key = ? LIMIT 1',
        [dayKey],
      );
      return _dailySummaryFromRow(row);
    } catch (error, stackTrace) {
      throw PomodoroPersistenceFailure(
        'Failed to set hydration reminder state',
        error,
        stackTrace,
      );
    }
  }

  @override
  Stream<DailyActivitySummary> watchDailySummary(String dayKey) {
    return _database
        .watch(
          'SELECT * FROM $dailyActivitySummaryTable WHERE day_key = ? LIMIT 1',
          parameters: [dayKey],
        )
        .where((rows) => rows.isNotEmpty)
        .map((rows) => _dailySummaryFromRow(rows.first));
  }

  @override
  Future<void> resetCurrentDay({
    required String dayKey,
    required DateTime now,
  }) async {
    try {
      await _database.writeTransaction((tx) async {
        await tx.execute(
          'DELETE FROM $sessionsTable WHERE day_key = ?',
          [dayKey],
        );
        await tx.execute(
          'DELETE FROM $wellnessEventsTable WHERE day_key = ?',
          [dayKey],
        );
        await tx.execute(
          'DELETE FROM $dailyActivitySummaryTable WHERE day_key = ?',
          [dayKey],
        );
      });
      await loadOrCreateDailySummary(dayKey: dayKey, openedAt: now);
    } catch (error, stackTrace) {
      throw PomodoroPersistenceFailure(
        'Failed to reset current day',
        error,
        stackTrace,
      );
    }
  }

  SessionRecord _sessionFromRow(Map<String, dynamic> row) {
    try {
      return SessionRecord(
        id: row['id'] as String,
        dayKey: row['day_key'] as String,
        type: _sessionTypeFromSql(row['type'] as String),
        plannedDurationSeconds: row['planned_duration_seconds'] as int,
        state: _sessionStateFromSql(row['state'] as String),
        outcome: (row['outcome'] as String?) != null
            ? _sessionOutcomeFromSql(row['outcome'] as String)
            : null,
        startedAt: DateTime.parse(row['started_at'] as String).toUtc(),
        lastResumedAt: DateTime.parse(row['last_resumed_at'] as String).toUtc(),
        pausedAt: (row['paused_at'] as String?) != null
            ? DateTime.parse(row['paused_at'] as String).toUtc()
            : null,
        endedAt: (row['ended_at'] as String?) != null
            ? DateTime.parse(row['ended_at'] as String).toUtc()
            : null,
        remainingSecondsAtPause: row['remaining_seconds_at_pause'] as int?,
      );
    } catch (error, stackTrace) {
      throw PomodoroCorruptStateFailure(
        'Invalid session row data',
        error,
        stackTrace,
      );
    }
  }

  WellnessEvent _wellnessFromRow(Map<String, dynamic> row) {
    try {
      return WellnessEvent(
        id: row['id'] as String,
        dayKey: row['day_key'] as String,
        type: _wellnessTypeFromSql(row['type'] as String),
        occurredAt: DateTime.parse(row['occurred_at'] as String).toUtc(),
      );
    } catch (error, stackTrace) {
      throw PomodoroCorruptStateFailure(
        'Invalid wellness row data',
        error,
        stackTrace,
      );
    }
  }

  DailyActivitySummary _dailySummaryFromRow(Map<String, dynamic> row) {
    try {
      return DailyActivitySummary(
        id: row['id'] as String,
        dayKey: row['day_key'] as String,
        endedFocusCount: row['ended_focus_count'] as int,
        endedBreakCount: row['ended_break_count'] as int,
        hydrationCount: row['hydration_count'] as int,
        movementCount: row['movement_count'] as int,
        lastHydrationAt: (row['last_hydration_at'] as String?) != null
            ? DateTime.parse(row['last_hydration_at'] as String).toUtc()
            : null,
        hydrationTimerAnchorAt: DateTime.parse(
          row['hydration_timer_anchor_at'] as String,
        ).toUtc(),
        hydrationReminderActive: (row['hydration_reminder_active'] as int) == 1,
        updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
      );
    } catch (error, stackTrace) {
      throw PomodoroCorruptStateFailure(
        'Invalid daily summary row data',
        error,
        stackTrace,
      );
    }
  }

  SessionType _sessionTypeFromSql(String value) {
    switch (value) {
      case 'focus':
        return SessionType.focus;
      case 'break':
        return SessionType.breakTime;
      default:
        throw PomodoroCorruptStateFailure('Unknown session type: $value');
    }
  }

  String _sessionTypeToSql(SessionType value) {
    switch (value) {
      case SessionType.focus:
        return 'focus';
      case SessionType.breakTime:
        return 'break';
    }
  }

  SessionLifecycleState _sessionStateFromSql(String value) {
    switch (value) {
      case 'active':
        return SessionLifecycleState.active;
      case 'paused':
        return SessionLifecycleState.paused;
      case 'ended':
        return SessionLifecycleState.ended;
      default:
        throw PomodoroCorruptStateFailure('Unknown session state: $value');
    }
  }

  SessionOutcome _sessionOutcomeFromSql(String value) {
    switch (value) {
      case 'completed':
        return SessionOutcome.completed;
      case 'stopped':
        return SessionOutcome.stopped;
      default:
        throw PomodoroCorruptStateFailure('Unknown session outcome: $value');
    }
  }

  String _sessionOutcomeToSql(SessionOutcome value) {
    switch (value) {
      case SessionOutcome.completed:
        return 'completed';
      case SessionOutcome.stopped:
        return 'stopped';
    }
  }

  WellnessEventType _wellnessTypeFromSql(String value) {
    switch (value) {
      case 'hydration':
        return WellnessEventType.hydration;
      case 'movement':
        return WellnessEventType.movement;
      default:
        throw PomodoroCorruptStateFailure(
          'Unknown wellness event type: $value',
        );
    }
  }

  String _wellnessTypeToSql(WellnessEventType value) {
    switch (value) {
      case WellnessEventType.hydration:
        return 'hydration';
      case WellnessEventType.movement:
        return 'movement';
    }
  }

  String _dailySummaryId(String dayKey) {
    final userId = _currentUserId();
    if (userId == null || userId.isEmpty) {
      throw PomodoroPersistenceFailure(
        'Failed to resolve the current authenticated user for daily summary storage',
      );
    }

    return '$userId:$dayKey';
  }

  Future<void> _writeDailySummary(
    dynamic executor,
    DailyActivitySummary summary,
  ) async {
    await executor.execute(
      '''
      UPDATE $dailyActivitySummaryTable
      SET ended_focus_count = ?,
          ended_break_count = ?,
          hydration_count = ?,
          movement_count = ?,
          last_hydration_at = ?,
          hydration_timer_anchor_at = ?,
          hydration_reminder_active = ?,
          updated_at = ?
      WHERE day_key = ?
      ''',
      [
        summary.endedFocusCount,
        summary.endedBreakCount,
        summary.hydrationCount,
        summary.movementCount,
        summary.lastHydrationAt?.toIso8601String(),
        summary.hydrationTimerAnchorAt.toIso8601String(),
        summary.hydrationReminderActive ? 1 : 0,
        summary.updatedAt.toIso8601String(),
        summary.dayKey,
      ],
    );
  }
}
