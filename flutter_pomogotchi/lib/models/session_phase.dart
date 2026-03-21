enum SessionPhase { idle, focusInProgress, breakInProgress }

extension SessionPhaseX on SessionPhase {
  String get wireValue {
    return switch (this) {
      SessionPhase.idle => 'idle',
      SessionPhase.focusInProgress => 'focus_in_progress',
      SessionPhase.breakInProgress => 'break_in_progress',
    };
  }

  String get label {
    return switch (this) {
      SessionPhase.idle => 'Idle',
      SessionPhase.focusInProgress => 'Focus in progress',
      SessionPhase.breakInProgress => 'Break in progress',
    };
  }
}
