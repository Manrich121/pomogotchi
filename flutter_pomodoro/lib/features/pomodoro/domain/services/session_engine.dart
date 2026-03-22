import 'package:flutter_pomodoro/features/pomodoro/domain/models/session_record.dart';

class SessionEngine {
  static const int defaultFocusDurationSeconds = 40 * 60;
  static const int defaultBreakDurationSeconds = 10 * 60;

  int plannedDurationFor(SessionType type) {
    return type == SessionType.focus
        ? defaultFocusDurationSeconds
        : defaultBreakDurationSeconds;
  }

  int remainingSeconds(SessionRecord session, DateTime now) {
    if (session.state == SessionLifecycleState.ended) {
      return 0;
    }
    if (session.state == SessionLifecycleState.paused) {
      return session.remainingSecondsAtPause ?? session.plannedDurationSeconds;
    }

    final base =
        session.remainingSecondsAtPause ?? session.plannedDurationSeconds;
    final elapsed = now
        .toUtc()
        .difference(session.lastResumedAt.toUtc())
        .inSeconds;
    final remaining = base - elapsed;
    return remaining <= 0 ? 0 : remaining;
  }

  SessionRecord pause(SessionRecord session, DateTime now) {
    final remaining = remainingSeconds(session, now);
    return session.copyWith(
      state: SessionLifecycleState.paused,
      pausedAt: now.toUtc(),
      remainingSecondsAtPause: remaining,
    );
  }

  SessionRecord resume(SessionRecord session, DateTime now) {
    return session.copyWith(
      state: SessionLifecycleState.active,
      lastResumedAt: now.toUtc(),
      pausedAt: null,
    );
  }

  SessionRecord end(
    SessionRecord session,
    DateTime now,
    SessionOutcome outcome,
  ) {
    return session.copyWith(
      state: SessionLifecycleState.ended,
      outcome: outcome,
      endedAt: now.toUtc(),
      pausedAt: null,
    );
  }
}
