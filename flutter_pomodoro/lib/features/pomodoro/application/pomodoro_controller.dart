import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_pomodoro/features/pomodoro/application/pomodoro_repository.dart';
import 'package:flutter_pomodoro/features/pomodoro/application/pomodoro_view_state.dart';
import 'package:flutter_pomodoro/features/pomodoro/domain/services/session_engine.dart';
import 'package:flutter_pomodoro/features/pomodoro/domain/models/daily_activity_summary.dart';
import 'package:flutter_pomodoro/features/pomodoro/domain/models/session_record.dart';
import 'package:flutter_pomodoro/shared/services/app_clock.dart';
import 'package:flutter_pomodoro/shared/services/app_lifecycle_service.dart';

class PomodoroController extends ChangeNotifier {
  PomodoroController({
    required PomodoroRepository repository,
    required AppClock clock,
    required AppLifecycleService lifecycleService,
    SessionEngine? sessionEngine,
  }) : _repository = repository,
       _clock = clock,
       _lifecycleService = lifecycleService,
       _sessionEngine = sessionEngine ?? SessionEngine();

  final PomodoroRepository _repository;
  final AppClock _clock;
  final AppLifecycleService _lifecycleService;
  final SessionEngine _sessionEngine;

  PomodoroViewState _state = const PomodoroViewState(
    status: PomodoroScreenStatus.loading,
  );

  PomodoroViewState get state => _state;

  StreamSubscription<DailyActivitySummary>? _summarySubscription;
  StreamSubscription<SessionRecord?>? _activeSessionSubscription;
  StreamSubscription<List<SessionRecord>>? _sessionsSubscription;
  StreamSubscription<AppLifecycleState>? _lifecycleSubscription;
  Timer? _ticker;
  PomodoroScreenStatus? _completionStatus;
  late String _todayDayKey;

  Future<void> initialize() async {
    _stopTicker();
    await _summarySubscription?.cancel();
    await _activeSessionSubscription?.cancel();
    await _sessionsSubscription?.cancel();
    await _lifecycleSubscription?.cancel();

    _setState(const PomodoroViewState(status: PomodoroScreenStatus.loading));
    final now = _clock.now();
    final dayKey = _dayKey(now);
    _todayDayKey = dayKey;

    try {
      final summary = await _repository.loadOrCreateDailySummary(
        dayKey: dayKey,
        openedAt: now,
      );
      final activeSession = await _repository.loadActiveSession();
      final initialStatus = activeSession != null
          ? _statusForSession(activeSession)
          : PomodoroScreenStatus.idle;
      final initialRemaining = activeSession != null
          ? _sessionEngine.remainingSeconds(activeSession, now)
          : null;
      _completionStatus = null;
      _setState(
        PomodoroViewState(
          status: initialStatus,
          activeSession: activeSession,
          dailySummary: summary,
          remainingSeconds: initialRemaining,
        ),
      );
      _syncTickerForState();

      _summarySubscription = _repository.watchDailySummary(dayKey).listen((
        updatedSummary,
      ) {
        _setState(_state.copyWith(dailySummary: updatedSummary));
      });

      _activeSessionSubscription = _repository.watchActiveSession().listen((
        activeSession,
      ) {
        final nextStatus = activeSession != null
            ? _statusForSession(activeSession)
            : _statusWhenNoActiveSession();
        final nextRemaining = activeSession != null
            ? _sessionEngine.remainingSeconds(activeSession, _clock.now())
            : null;
        _setState(
          _state.copyWith(
            activeSession: activeSession,
            status: nextStatus,
            remainingSeconds: nextRemaining,
            errorMessage: null,
          ),
        );
        _syncTickerForState();
      });

      _sessionsSubscription = _repository.watchTodaySessions(dayKey).listen((
        sessions,
      ) {
        SessionRecord? latestEndedCompleted;
        for (final session in sessions) {
          if (latestEndedCompleted == null &&
              session.state == SessionLifecycleState.ended &&
              session.outcome == SessionOutcome.completed) {
            latestEndedCompleted = session;
          }
        }

        final activeSession = _state.activeSession;
        if (activeSession != null) {
          _completionStatus = null;
        } else if (latestEndedCompleted != null) {
          _completionStatus = _statusForSession(latestEndedCompleted);
        }
        final nextStatus = activeSession != null
            ? _statusForSession(activeSession)
            : _statusWhenNoActiveSession(
                completedSession: latestEndedCompleted,
              );
        final nextRemaining = activeSession != null
            ? _sessionEngine.remainingSeconds(activeSession, _clock.now())
            : null;
        _setState(
          _state.copyWith(
            status: nextStatus,
            remainingSeconds: nextRemaining,
            errorMessage: null,
          ),
        );
        _syncTickerForState();
      });

      _lifecycleSubscription = _lifecycleService.stream.listen((_) {});
    } catch (error) {
      _setState(
        PomodoroViewState(
          status: PomodoroScreenStatus.error,
          errorMessage: error.toString(),
          dailySummary: _state.dailySummary,
          activeSession: _state.activeSession,
        ),
      );
    }
  }

  Future<void> retry() async {
    await initialize();
  }

  Future<void> startFocusSession() async {
    await _startSession(SessionType.focus);
  }

  Future<void> startBreakSession() async {
    await _startSession(SessionType.breakTime);
  }

  Future<void> pauseSession() async {
    final session = _state.activeSession;
    if (session == null || session.state != SessionLifecycleState.active) {
      return;
    }
    final now = _clock.now();
    final remaining = _sessionEngine.remainingSeconds(session, now);
    final paused = await _repository.pauseSession(
      sessionId: session.id,
      pausedAt: now,
      remainingSecondsAtPause: remaining,
    );
    _setState(
      _state.copyWith(
        activeSession: paused,
        status: _statusForSession(paused),
        remainingSeconds: remaining,
      ),
    );
    _syncTickerForState();
  }

  Future<void> resumeSession() async {
    final session = _state.activeSession;
    if (session == null || session.state != SessionLifecycleState.paused) {
      return;
    }
    final now = _clock.now();
    final resumed = await _repository.resumeSession(
      sessionId: session.id,
      resumedAt: now,
    );
    _setState(
      _state.copyWith(
        activeSession: resumed,
        status: _statusForSession(resumed),
        remainingSeconds: _sessionEngine.remainingSeconds(resumed, now),
      ),
    );
    _syncTickerForState();
  }

  Future<void> stopSession() async {
    final session = _state.activeSession;
    if (session == null) {
      return;
    }
    await _repository.endSession(
      sessionId: session.id,
      endedAt: _clock.now(),
      outcome: SessionOutcome.stopped,
    );
    _completionStatus = null;
    _setState(
      _state.copyWith(
        status: PomodoroScreenStatus.idle,
        activeSession: null,
        remainingSeconds: null,
      ),
    );
    _syncTickerForState();
  }

  void resetCompletionPrompt() {
    _completionStatus = null;
    if (_state.activeSession == null) {
      _setState(
        _state.copyWith(
          status: PomodoroScreenStatus.idle,
          remainingSeconds: null,
        ),
      );
    }
  }

  @override
  void dispose() {
    _stopTicker();
    unawaited(_summarySubscription?.cancel());
    unawaited(_activeSessionSubscription?.cancel());
    unawaited(_sessionsSubscription?.cancel());
    unawaited(_lifecycleSubscription?.cancel());
    super.dispose();
  }

  void _setState(PomodoroViewState next) {
    _state = next;
    notifyListeners();
  }

  String _dayKey(DateTime value) {
    final utc = value.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  PomodoroScreenStatus _statusForSession(SessionRecord? session) {
    if (session == null) {
      return PomodoroScreenStatus.idle;
    }

    if (session.state == SessionLifecycleState.active) {
      return session.type == SessionType.focus
          ? PomodoroScreenStatus.focusActive
          : PomodoroScreenStatus.breakActive;
    }

    if (session.state == SessionLifecycleState.paused) {
      return session.type == SessionType.focus
          ? PomodoroScreenStatus.focusPaused
          : PomodoroScreenStatus.breakPaused;
    }

    if (session.outcome == SessionOutcome.completed) {
      return session.type == SessionType.focus
          ? PomodoroScreenStatus.focusCompleted
          : PomodoroScreenStatus.breakCompleted;
    }

    return PomodoroScreenStatus.idle;
  }

  PomodoroScreenStatus _statusWhenNoActiveSession({
    SessionRecord? completedSession,
  }) {
    final completionStatus = _completionStatus;
    if (completionStatus != null) {
      return completionStatus;
    }

    if (completedSession != null) {
      return _statusForSession(completedSession);
    }

    if (_state.status == PomodoroScreenStatus.focusCompleted ||
        _state.status == PomodoroScreenStatus.breakCompleted) {
      return _state.status;
    }

    return PomodoroScreenStatus.idle;
  }

  Future<void> _startSession(SessionType type) async {
    final now = _clock.now();
    _completionStatus = null;
    final created = await _repository.createSession(
      type: type,
      startedAt: now,
      plannedDurationSeconds: _sessionEngine.plannedDurationFor(type),
      dayKey: _todayDayKey,
    );
    _setState(
      _state.copyWith(
        activeSession: created,
        status: _statusForSession(created),
        remainingSeconds: _sessionEngine.remainingSeconds(created, now),
        errorMessage: null,
      ),
    );
    _syncTickerForState();
  }

  void _syncTickerForState() {
    final session = _state.activeSession;
    if (session != null && session.state == SessionLifecycleState.active) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
      return;
    }
    _stopTicker();
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _onTick() async {
    final session = _state.activeSession;
    if (session == null || session.state != SessionLifecycleState.active) {
      _stopTicker();
      return;
    }
    final now = _clock.now();
    final remaining = _sessionEngine.remainingSeconds(session, now);
    if (remaining <= 0) {
      await _repository.endSession(
        sessionId: session.id,
        endedAt: now,
        outcome: SessionOutcome.completed,
      );
      _completionStatus = session.type == SessionType.focus
          ? PomodoroScreenStatus.focusCompleted
          : PomodoroScreenStatus.breakCompleted;
      _setState(
        _state.copyWith(
          status: _completionStatus,
          activeSession: null,
          remainingSeconds: 0,
        ),
      );
      _stopTicker();
      return;
    }
    _setState(_state.copyWith(remainingSeconds: remaining));
  }
}
