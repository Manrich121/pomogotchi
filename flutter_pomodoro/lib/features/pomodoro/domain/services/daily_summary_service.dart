import 'package:flutter_pomodoro/features/pomodoro/domain/models/daily_activity_summary.dart';
import 'package:flutter_pomodoro/features/pomodoro/domain/models/session_record.dart';
import 'package:flutter_pomodoro/features/pomodoro/domain/models/wellness_event.dart';

class DailySummaryService {
  const DailySummaryService();

  DailyActivitySummary create({
    required String id,
    required String dayKey,
    required DateTime openedAt,
  }) {
    final openedAtUtc = openedAt.toUtc();
    return DailyActivitySummary(
      id: id,
      dayKey: dayKey,
      endedFocusCount: 0,
      endedBreakCount: 0,
      hydrationCount: 0,
      movementCount: 0,
      hydrationTimerAnchorAt: openedAtUtc,
      hydrationReminderActive: false,
      updatedAt: openedAtUtc,
    );
  }

  DailyActivitySummary applyEndedSession({
    required DailyActivitySummary summary,
    required SessionRecord session,
    required DateTime endedAt,
  }) {
    final endedAtUtc = endedAt.toUtc();
    return DailyActivitySummary(
      id: summary.id,
      dayKey: summary.dayKey,
      endedFocusCount:
          summary.endedFocusCount + (session.type == SessionType.focus ? 1 : 0),
      endedBreakCount:
          summary.endedBreakCount +
          (session.type == SessionType.breakTime ? 1 : 0),
      hydrationCount: summary.hydrationCount,
      movementCount: summary.movementCount,
      lastHydrationAt: summary.lastHydrationAt,
      hydrationTimerAnchorAt: summary.hydrationTimerAnchorAt,
      hydrationReminderActive: summary.hydrationReminderActive,
      updatedAt: endedAtUtc,
    );
  }

  DailyActivitySummary applyWellnessEvent({
    required DailyActivitySummary summary,
    required WellnessEvent event,
  }) {
    final occurredAtUtc = event.occurredAt.toUtc();
    final isHydration = event.type == WellnessEventType.hydration;

    return DailyActivitySummary(
      id: summary.id,
      dayKey: summary.dayKey,
      endedFocusCount: summary.endedFocusCount,
      endedBreakCount: summary.endedBreakCount,
      hydrationCount: summary.hydrationCount + (isHydration ? 1 : 0),
      movementCount: summary.movementCount + (isHydration ? 0 : 1),
      lastHydrationAt: isHydration ? occurredAtUtc : summary.lastHydrationAt,
      hydrationTimerAnchorAt: isHydration
          ? occurredAtUtc
          : summary.hydrationTimerAnchorAt,
      hydrationReminderActive: isHydration
          ? false
          : summary.hydrationReminderActive,
      updatedAt: occurredAtUtc,
    );
  }

  DailyActivitySummary aggregate({
    required DailyActivitySummary summary,
    required Iterable<SessionRecord> sessions,
    required Iterable<WellnessEvent> wellnessEvents,
    required DateTime now,
  }) {
    var endedFocusCount = 0;
    var endedBreakCount = 0;
    var hydrationCount = 0;
    var movementCount = 0;
    DateTime? lastHydrationAt = summary.lastHydrationAt;

    for (final session in sessions) {
      if (session.state != SessionLifecycleState.ended) {
        continue;
      }

      if (session.type == SessionType.focus) {
        endedFocusCount += 1;
      } else {
        endedBreakCount += 1;
      }
    }

    for (final event in wellnessEvents) {
      if (event.type == WellnessEventType.hydration) {
        hydrationCount += 1;
        final occurredAtUtc = event.occurredAt.toUtc();
        if (lastHydrationAt == null || occurredAtUtc.isAfter(lastHydrationAt)) {
          lastHydrationAt = occurredAtUtc;
        }
      } else {
        movementCount += 1;
      }
    }

    return DailyActivitySummary(
      id: summary.id,
      dayKey: summary.dayKey,
      endedFocusCount: endedFocusCount,
      endedBreakCount: endedBreakCount,
      hydrationCount: hydrationCount,
      movementCount: movementCount,
      lastHydrationAt: lastHydrationAt,
      hydrationTimerAnchorAt: lastHydrationAt ?? summary.hydrationTimerAnchorAt,
      hydrationReminderActive: lastHydrationAt == null
          ? summary.hydrationReminderActive
          : false,
      updatedAt: now.toUtc(),
    );
  }
}
