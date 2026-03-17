enum SessionType { focus, breakTime }

enum SessionLifecycleState { active, paused, ended }

enum SessionOutcome { completed, stopped }

class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.dayKey,
    required this.type,
    required this.plannedDurationSeconds,
    required this.state,
    required this.startedAt,
    required this.lastResumedAt,
    this.outcome,
    this.pausedAt,
    this.endedAt,
    this.remainingSecondsAtPause,
  });

  final String id;
  final String dayKey;
  final SessionType type;
  final int plannedDurationSeconds;
  final SessionLifecycleState state;
  final SessionOutcome? outcome;
  final DateTime startedAt;
  final DateTime lastResumedAt;
  final DateTime? pausedAt;
  final DateTime? endedAt;
  final int? remainingSecondsAtPause;

  bool get isActiveOrPaused =>
      state == SessionLifecycleState.active ||
      state == SessionLifecycleState.paused;

  SessionRecord copyWith({
    String? id,
    String? dayKey,
    SessionType? type,
    int? plannedDurationSeconds,
    SessionLifecycleState? state,
    SessionOutcome? outcome,
    DateTime? startedAt,
    DateTime? lastResumedAt,
    DateTime? pausedAt,
    DateTime? endedAt,
    int? remainingSecondsAtPause,
  }) {
    return SessionRecord(
      id: id ?? this.id,
      dayKey: dayKey ?? this.dayKey,
      type: type ?? this.type,
      plannedDurationSeconds:
          plannedDurationSeconds ?? this.plannedDurationSeconds,
      state: state ?? this.state,
      outcome: outcome ?? this.outcome,
      startedAt: startedAt ?? this.startedAt,
      lastResumedAt: lastResumedAt ?? this.lastResumedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      endedAt: endedAt ?? this.endedAt,
      remainingSecondsAtPause:
          remainingSecondsAtPause ?? this.remainingSecondsAtPause,
    );
  }
}
