import 'package:flutter_pomodoro/features/pomodoro/domain/models/session_record.dart';
import 'package:flutter_pomodoro/features/pomodoro/domain/models/wellness_event.dart';
import 'package:flutter_pomodoro/features/pomodoro/domain/services/daily_summary_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = DailySummaryService();
  final openedAt = DateTime.utc(2026, 1, 1, 9);

  test('aggregates ended sessions for both completed and stopped outcomes', () {
    final summary = service.create(
      id: 'summary-1',
      dayKey: '2026-01-01',
      openedAt: openedAt,
    );

    final aggregated = service.aggregate(
      summary: summary,
      sessions: [
        SessionRecord(
          id: 'focus-complete',
          dayKey: '2026-01-01',
          type: SessionType.focus,
          plannedDurationSeconds: 2400,
          state: SessionLifecycleState.ended,
          outcome: SessionOutcome.completed,
          startedAt: openedAt,
          lastResumedAt: openedAt,
          endedAt: openedAt.add(const Duration(minutes: 40)),
        ),
        SessionRecord(
          id: 'focus-stopped',
          dayKey: '2026-01-01',
          type: SessionType.focus,
          plannedDurationSeconds: 2400,
          state: SessionLifecycleState.ended,
          outcome: SessionOutcome.stopped,
          startedAt: openedAt.add(const Duration(hours: 1)),
          lastResumedAt: openedAt.add(const Duration(hours: 1)),
          endedAt: openedAt.add(const Duration(hours: 1, minutes: 10)),
        ),
        SessionRecord(
          id: 'break-stopped',
          dayKey: '2026-01-01',
          type: SessionType.breakTime,
          plannedDurationSeconds: 600,
          state: SessionLifecycleState.ended,
          outcome: SessionOutcome.stopped,
          startedAt: openedAt.add(const Duration(hours: 2)),
          lastResumedAt: openedAt.add(const Duration(hours: 2)),
          endedAt: openedAt.add(const Duration(hours: 2, minutes: 5)),
        ),
        SessionRecord(
          id: 'active-focus',
          dayKey: '2026-01-01',
          type: SessionType.focus,
          plannedDurationSeconds: 2400,
          state: SessionLifecycleState.active,
          startedAt: openedAt.add(const Duration(hours: 3)),
          lastResumedAt: openedAt.add(const Duration(hours: 3)),
        ),
      ],
      wellnessEvents: const [],
      now: openedAt.add(const Duration(hours: 4)),
    );

    expect(aggregated.endedFocusCount, 2);
    expect(aggregated.endedBreakCount, 1);
  });

  test(
    'applies movement and hydration events without losing reminder anchors',
    () {
      final startingSummary = service.create(
        id: 'summary-1',
        dayKey: '2026-01-01',
        openedAt: openedAt,
      );

      final afterMovement = service.applyWellnessEvent(
        summary: startingSummary,
        event: WellnessEvent(
          id: 'event-move',
          dayKey: '2026-01-01',
          type: WellnessEventType.movement,
          occurredAt: openedAt.add(const Duration(minutes: 20)),
        ),
      );

      expect(afterMovement.movementCount, 1);
      expect(afterMovement.hydrationCount, 0);
      expect(afterMovement.hydrationTimerAnchorAt, openedAt);

      final reminderVisible = afterMovement.copyWith(
        hydrationReminderActive: true,
        updatedAt: openedAt.add(const Duration(hours: 1)),
      );
      final afterHydration = service.applyWellnessEvent(
        summary: reminderVisible,
        event: WellnessEvent(
          id: 'event-water',
          dayKey: '2026-01-01',
          type: WellnessEventType.hydration,
          occurredAt: openedAt.add(const Duration(hours: 1, minutes: 5)),
        ),
      );

      expect(afterHydration.hydrationCount, 1);
      expect(afterHydration.movementCount, 1);
      expect(
        afterHydration.lastHydrationAt,
        openedAt.add(const Duration(hours: 1, minutes: 5)),
      );
      expect(
        afterHydration.hydrationTimerAnchorAt,
        openedAt.add(const Duration(hours: 1, minutes: 5)),
      );
      expect(afterHydration.hydrationReminderActive, isFalse);
    },
  );
}
