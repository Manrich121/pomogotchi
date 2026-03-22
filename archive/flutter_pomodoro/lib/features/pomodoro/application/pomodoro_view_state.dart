import 'package:flutter_pomodoro/features/pomodoro/domain/models/daily_activity_summary.dart';
import 'package:flutter_pomodoro/features/pomodoro/domain/models/session_record.dart';

enum PomodoroScreenStatus {
  loading,
  idle,
  focusActive,
  focusPaused,
  breakActive,
  breakPaused,
  focusCompleted,
  breakCompleted,
  error,
}

class PomodoroViewState {
  const PomodoroViewState({
    required this.status,
    this.activeSession,
    this.dailySummary,
    this.remainingSeconds,
    this.errorMessage,
  });

  final PomodoroScreenStatus status;
  final SessionRecord? activeSession;
  final DailyActivitySummary? dailySummary;
  final int? remainingSeconds;
  final String? errorMessage;

  bool get isLoading => status == PomodoroScreenStatus.loading;
  bool get isError => status == PomodoroScreenStatus.error;

  PomodoroViewState copyWith({
    PomodoroScreenStatus? status,
    Object? activeSession = _noChange,
    Object? dailySummary = _noChange,
    Object? remainingSeconds = _noChange,
    Object? errorMessage = _noChange,
  }) {
    return PomodoroViewState(
      status: status ?? this.status,
      activeSession: activeSession == _noChange
          ? this.activeSession
          : activeSession as SessionRecord?,
      dailySummary: dailySummary == _noChange
          ? this.dailySummary
          : dailySummary as DailyActivitySummary?,
      remainingSeconds: remainingSeconds == _noChange
          ? this.remainingSeconds
          : remainingSeconds as int?,
      errorMessage: errorMessage == _noChange
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const _noChange = Object();
