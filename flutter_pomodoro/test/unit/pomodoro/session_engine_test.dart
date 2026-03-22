import 'package:flutter_pomodoro/features/pomodoro/domain/models/session_record.dart';
import 'package:flutter_pomodoro/features/pomodoro/domain/services/session_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = SessionEngine();

  test('returns 40 minutes for focus and 10 minutes for break', () {
    expect(engine.plannedDurationFor(SessionType.focus), 2400);
    expect(engine.plannedDurationFor(SessionType.breakTime), 600);
  });

  test('countdown math for active session is timestamp based', () {
    final startedAt = DateTime.utc(2026, 1, 1, 12);
    final session = SessionRecord(
      id: 'session-1',
      dayKey: '2026-01-01',
      type: SessionType.focus,
      plannedDurationSeconds: 2400,
      state: SessionLifecycleState.active,
      startedAt: startedAt,
      lastResumedAt: startedAt,
    );

    expect(
      engine.remainingSeconds(
        session,
        startedAt.add(const Duration(seconds: 10)),
      ),
      2390,
    );
    expect(
      engine.remainingSeconds(
        session,
        startedAt.add(const Duration(minutes: 40)),
      ),
      0,
    );
  });

  test('pause and resume transitions retain remaining time base', () {
    final startedAt = DateTime.utc(2026, 1, 1, 12);
    final active = SessionRecord(
      id: 'session-2',
      dayKey: '2026-01-01',
      type: SessionType.focus,
      plannedDurationSeconds: 2400,
      state: SessionLifecycleState.active,
      startedAt: startedAt,
      lastResumedAt: startedAt,
    );

    final paused = engine.pause(
      active,
      startedAt.add(const Duration(seconds: 125)),
    );
    expect(paused.state, SessionLifecycleState.paused);
    expect(paused.remainingSecondsAtPause, 2275);

    final resumed = engine.resume(
      paused,
      startedAt.add(const Duration(seconds: 200)),
    );
    expect(resumed.state, SessionLifecycleState.active);
    expect(
      engine.remainingSeconds(
        resumed,
        startedAt.add(const Duration(seconds: 260)),
      ),
      2215,
    );
  });

  test('end transition marks session ended with outcome', () {
    final startedAt = DateTime.utc(2026, 1, 1, 12);
    final active = SessionRecord(
      id: 'session-3',
      dayKey: '2026-01-01',
      type: SessionType.breakTime,
      plannedDurationSeconds: 600,
      state: SessionLifecycleState.active,
      startedAt: startedAt,
      lastResumedAt: startedAt,
    );

    final ended = engine.end(
      active,
      startedAt.add(const Duration(minutes: 10)),
      SessionOutcome.completed,
    );

    expect(ended.state, SessionLifecycleState.ended);
    expect(ended.outcome, SessionOutcome.completed);
    expect(
      engine.remainingSeconds(
        ended,
        startedAt.add(const Duration(minutes: 11)),
      ),
      0,
    );
  });
}
