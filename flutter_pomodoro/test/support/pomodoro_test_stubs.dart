import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_pomodoro/features/pomodoro/application/pomodoro_repository.dart';
import 'package:flutter_pomodoro/features/pomodoro/data/pomodoro_database.dart';
import 'package:flutter_pomodoro/features/pomodoro/domain/models/daily_activity_summary.dart';
import 'package:flutter_pomodoro/features/pomodoro/domain/models/session_record.dart';
import 'package:flutter_pomodoro/features/pomodoro/domain/models/wellness_event.dart';
import 'package:flutter_pomodoro/shared/services/app_clock.dart';
import 'package:flutter_pomodoro/shared/services/app_lifecycle_service.dart';
import 'package:powersync/powersync.dart';

class MutableClock implements AppClock {
  MutableClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}

class FakeLifecycleService implements AppLifecycleService {
  final StreamController<AppLifecycleState> _controller =
      StreamController<AppLifecycleState>.broadcast();

  AppLifecycleState _state = AppLifecycleState.resumed;

  @override
  AppLifecycleState get currentState => _state;

  @override
  Stream<AppLifecycleState> get stream => _controller.stream;

  void emit(AppLifecycleState state) {
    _state = state;
    _controller.add(state);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

class InMemoryPomodoroRepository implements PomodoroRepository {
  final List<SessionRecord> _sessions = [];
  final List<WellnessEvent> _events = [];
  final Map<String, DailyActivitySummary> _summaries = {};
  final StreamController<List<SessionRecord>> _sessionsController =
      StreamController<List<SessionRecord>>.broadcast(sync: true);
  final StreamController<SessionRecord?> _activeSessionController =
      StreamController<SessionRecord?>.broadcast(sync: true);
  final StreamController<List<WellnessEvent>> _eventsController =
      StreamController<List<WellnessEvent>>.broadcast(sync: true);
  final StreamController<DailyActivitySummary> _summaryController =
      StreamController<DailyActivitySummary>.broadcast(sync: true);

  int _idCounter = 0;
  bool _disposed = false;

  void seedSession(SessionRecord session) {
    _sessions.insert(0, session);
  }

  void syncRemoteSession(SessionRecord session) {
    _sessions.removeWhere((existing) => existing.id == session.id);
    _sessions.insert(0, session);
    _emitSessions();
    _emitActiveSession();
  }

  @override
  Future<SessionRecord?> loadActiveSession() async {
    return _currentActiveSession();
  }

  @override
  Stream<SessionRecord?> watchActiveSession() {
    return Stream.multi((controller) {
      controller.add(_currentActiveSession());
      final subscription = _activeSessionController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<SessionRecord> createSession({
    required SessionType type,
    required DateTime startedAt,
    required int plannedDurationSeconds,
    required String dayKey,
  }) async {
    final id = 'session-${++_idCounter}';
    final session = SessionRecord(
      id: id,
      dayKey: dayKey,
      type: type,
      plannedDurationSeconds: plannedDurationSeconds,
      state: SessionLifecycleState.active,
      startedAt: startedAt.toUtc(),
      lastResumedAt: startedAt.toUtc(),
    );
    _sessions.insert(0, session);
    _emitSessions();
    _emitActiveSession();
    return session;
  }

  @override
  Future<SessionRecord> pauseSession({
    required String sessionId,
    required DateTime pausedAt,
    required int remainingSecondsAtPause,
  }) async {
    final index = _sessions.indexWhere((session) => session.id == sessionId);
    final session = _sessions[index].copyWith(
      state: SessionLifecycleState.paused,
      pausedAt: pausedAt.toUtc(),
      remainingSecondsAtPause: remainingSecondsAtPause,
    );
    _sessions[index] = session;
    _emitSessions();
    _emitActiveSession();
    return session;
  }

  @override
  Future<SessionRecord> resumeSession({
    required String sessionId,
    required DateTime resumedAt,
  }) async {
    final index = _sessions.indexWhere((session) => session.id == sessionId);
    final session = _sessions[index].copyWith(
      state: SessionLifecycleState.active,
      lastResumedAt: resumedAt.toUtc(),
      pausedAt: null,
    );
    _sessions[index] = session;
    _emitSessions();
    _emitActiveSession();
    return session;
  }

  @override
  Future<SessionRecord> endSession({
    required String sessionId,
    required DateTime endedAt,
    required SessionOutcome outcome,
  }) async {
    final index = _sessions.indexWhere((session) => session.id == sessionId);
    final current = _sessions[index];
    final ended = current.copyWith(
      state: SessionLifecycleState.ended,
      outcome: outcome,
      endedAt: endedAt.toUtc(),
      pausedAt: null,
    );
    _sessions[index] = ended;
    final summary = _summaries[current.dayKey];
    if (summary != null) {
      _summaries[current.dayKey] = summary.copyWith(
        endedFocusCount: current.type == SessionType.focus
            ? summary.endedFocusCount + 1
            : summary.endedFocusCount,
        endedBreakCount: current.type == SessionType.breakTime
            ? summary.endedBreakCount + 1
            : summary.endedBreakCount,
        updatedAt: endedAt.toUtc(),
      );
      if (!_disposed && !_summaryController.isClosed) {
        _summaryController.add(_summaries[current.dayKey]!);
      }
    }
    _emitSessions();
    _emitActiveSession();
    return ended;
  }

  @override
  Stream<List<SessionRecord>> watchTodaySessions(String dayKey) {
    return Stream.multi((controller) {
      controller.add(
        _sessions
            .where((session) => session.dayKey == dayKey)
            .toList(growable: false),
      );
      final subscription = _sessionsController.stream.listen(
        (sessions) {
          controller.add(
            sessions
                .where((session) => session.dayKey == dayKey)
                .toList(growable: false),
          );
        },
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<WellnessEvent> addWellnessEvent({
    required WellnessEventType type,
    required DateTime occurredAt,
    required String dayKey,
  }) async {
    final event = WellnessEvent(
      id: 'event-${++_idCounter}',
      dayKey: dayKey,
      type: type,
      occurredAt: occurredAt.toUtc(),
    );
    _events.insert(0, event);
    if (!_disposed && !_eventsController.isClosed) {
      _eventsController.add(
        _events.where((event) => event.dayKey == dayKey).toList(),
      );
    }
    return event;
  }

  @override
  Stream<List<WellnessEvent>> watchTodayWellnessEvents(String dayKey) {
    Future<void>.microtask(() {
      if (!_disposed && !_eventsController.isClosed) {
        _eventsController.add(
          _events.where((event) => event.dayKey == dayKey).toList(),
        );
      }
    });
    return _eventsController.stream;
  }

  @override
  Future<DailyActivitySummary> loadOrCreateDailySummary({
    required String dayKey,
    required DateTime openedAt,
  }) async {
    final existing = _summaries[dayKey];
    if (existing != null) {
      return existing;
    }
    final summary = DailyActivitySummary(
      id: 'summary-${++_idCounter}',
      dayKey: dayKey,
      endedFocusCount: 0,
      endedBreakCount: 0,
      hydrationCount: 0,
      movementCount: 0,
      hydrationTimerAnchorAt: openedAt.toUtc(),
      hydrationReminderActive: false,
      updatedAt: openedAt.toUtc(),
    );
    _summaries[dayKey] = summary;
    if (!_disposed && !_summaryController.isClosed) {
      _summaryController.add(summary);
    }
    return summary;
  }

  @override
  Future<DailyActivitySummary> refreshDailySummary({
    required String dayKey,
    required DateTime now,
  }) async {
    return loadOrCreateDailySummary(dayKey: dayKey, openedAt: now);
  }

  @override
  Future<DailyActivitySummary> setHydrationReminderState({
    required String dayKey,
    required DateTime anchorAt,
    required bool isActive,
  }) async {
    final summary = await loadOrCreateDailySummary(
      dayKey: dayKey,
      openedAt: anchorAt,
    );
    final updated = summary.copyWith(
      hydrationTimerAnchorAt: anchorAt.toUtc(),
      hydrationReminderActive: isActive,
      updatedAt: anchorAt.toUtc(),
    );
    _summaries[dayKey] = updated;
    if (!_disposed && !_summaryController.isClosed) {
      _summaryController.add(updated);
    }
    return updated;
  }

  @override
  Stream<DailyActivitySummary> watchDailySummary(String dayKey) {
    Future<void>.microtask(() async {
      if (_disposed || _summaryController.isClosed) {
        return;
      }
      final summary = await loadOrCreateDailySummary(
        dayKey: dayKey,
        openedAt: DateTime.now().toUtc(),
      );
      if (_disposed || _summaryController.isClosed) {
        return;
      }
      _summaryController.add(summary);
    });
    return _summaryController.stream;
  }

  SessionRecord? _currentActiveSession() {
    for (final session in _sessions) {
      if (session.state == SessionLifecycleState.active ||
          session.state == SessionLifecycleState.paused) {
        return session;
      }
    }
    return null;
  }

  void _emitActiveSession() {
    if (!_disposed && !_activeSessionController.isClosed) {
      _activeSessionController.add(_currentActiveSession());
    }
  }

  void _emitSessions() {
    if (!_disposed && !_sessionsController.isClosed) {
      _sessionsController.add(List<SessionRecord>.unmodifiable(_sessions));
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _sessionsController.close();
    await _activeSessionController.close();
    await _eventsController.close();
    await _summaryController.close();
  }
}

class PendingPomodoroDatabaseOwner extends PomodoroDatabaseOwner {
  PendingPomodoroDatabaseOwner();

  final Completer<PowerSyncDatabase> _completer =
      Completer<PowerSyncDatabase>();

  @override
  Future<PowerSyncDatabase> initialize() => _completer.future;

  @override
  Future<void> dispose() async {}
}
