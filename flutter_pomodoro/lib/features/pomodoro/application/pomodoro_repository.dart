import 'package:flutter_pomodoro/features/pomodoro/domain/models/daily_activity_summary.dart';
import 'package:flutter_pomodoro/features/pomodoro/domain/models/session_record.dart';
import 'package:flutter_pomodoro/features/pomodoro/domain/models/wellness_event.dart';

abstract class PomodoroRepository {
  Future<SessionRecord?> loadActiveSession();

  Stream<SessionRecord?> watchActiveSession();

  Future<SessionRecord> createSession({
    required SessionType type,
    required DateTime startedAt,
    required int plannedDurationSeconds,
    required String dayKey,
  });

  Future<SessionRecord> pauseSession({
    required String sessionId,
    required DateTime pausedAt,
    required int remainingSecondsAtPause,
  });

  Future<SessionRecord> resumeSession({
    required String sessionId,
    required DateTime resumedAt,
  });

  Future<SessionRecord> endSession({
    required String sessionId,
    required DateTime endedAt,
    required SessionOutcome outcome,
  });

  Stream<List<SessionRecord>> watchTodaySessions(String dayKey);

  Future<WellnessEvent> addWellnessEvent({
    required WellnessEventType type,
    required DateTime occurredAt,
    required String dayKey,
  });

  Stream<List<WellnessEvent>> watchTodayWellnessEvents(String dayKey);

  Future<DailyActivitySummary> loadOrCreateDailySummary({
    required String dayKey,
    required DateTime openedAt,
  });

  Future<DailyActivitySummary> refreshDailySummary({
    required String dayKey,
    required DateTime now,
  });

  Future<DailyActivitySummary> setHydrationReminderState({
    required String dayKey,
    required DateTime anchorAt,
    required bool isActive,
  });

  Stream<DailyActivitySummary> watchDailySummary(String dayKey);
}
