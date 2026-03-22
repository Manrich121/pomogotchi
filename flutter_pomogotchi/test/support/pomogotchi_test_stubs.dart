import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pomogotchi/agents/pet_agent.dart';
import 'package:pomogotchi/controllers/pet_session_controller.dart';
import 'package:pomogotchi/features/pomodoro/application/pomodoro_repository.dart';
import 'package:pomogotchi/features/pomodoro/domain/models/daily_activity_summary.dart';
import 'package:pomogotchi/features/pomodoro/domain/models/session_record.dart';
import 'package:pomogotchi/features/pomodoro/domain/models/wellness_event.dart';
import 'package:pomogotchi/features/pomodoro/domain/services/daily_summary_service.dart';
import 'package:pomogotchi/models/animal_spec.dart';
import 'package:pomogotchi/models/pet_bio.dart';
import 'package:pomogotchi/models/pet_event.dart';
import 'package:pomogotchi/models/pet_reaction.dart';
import 'package:pomogotchi/models/pet_session.dart';
import 'package:pomogotchi/models/pet_transcript_entry.dart';
import 'package:pomogotchi/models/session_phase.dart';
import 'package:pomogotchi/shared/services/app_clock.dart';
import 'package:pomogotchi/shared/services/app_lifecycle_service.dart';

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

class FakePetAgent implements PetAgent {
  FakePetAgent({this.shouldThrow = false});

  final bool shouldThrow;
  final List<PetEvent> events = [];

  @override
  Future<PetReaction> reactStream({
    required PetEvent event,
    required SessionPhase sessionPhase,
    required PetBio bio,
    required AnimalSpec animalSpec,
    required List<PetTranscriptEntry> transcript,
    required void Function(String chunk) onChunk,
  }) async {
    events.add(event);
    if (shouldThrow) {
      throw Exception('pet reaction failed');
    }

    final speech = switch (event) {
      PetEvent.startFocusSession =>
        'Focus face on. I am perched right here with you.',
      PetEvent.completeFocusSession =>
        'That was strong work. Take the win, then breathe out.',
      PetEvent.stopFocusSessionEarly =>
        'That one got cut short. I am still with you.',
      PetEvent.startBreak => 'Break time. Let your shoulders drop a little.',
      PetEvent.completeBreak => 'Break wrapped. You look steadier already.',
      PetEvent.stopBreakEarly => 'Short break, but it still counted.',
      PetEvent.drinkWater => 'Tiny sip, strong recovery.',
      PetEvent.moveOrStretch => 'Stretching counts. I saw that.',
      PetEvent.petPet => 'Okay, that was an excellent pet pet.',
    };

    onChunk(speech.substring(0, speech.length ~/ 2));
    onChunk(speech.substring(speech.length ~/ 2));

    return PetReaction(speech: speech);
  }

  @override
  void dispose() {}
}

PetSessionController buildTestPetSessionController({FakePetAgent? petAgent}) {
  return TestPetSessionController(petAgent: petAgent ?? FakePetAgent());
}

class TestPetSessionController extends PetSessionController {
  TestPetSessionController({required this.petAgent});

  static const _testBio = PetBio(
    name: 'Bernie',
    summary: 'A scrappy little hype machine with a soft spot for effort.',
  );

  final FakePetAgent petAgent;

  PetSession _session = PetSession.initial();

  @override
  PetSession get session => _session;

  @override
  Future<void> bootstrap() async {
    _session = PetSession.initial().copyWith(
      animal: AnimalSpec.fromAnimalAsset('assets/animals/dog.png'),
      bio: _testBio,
      latestReaction: PetReaction(speech: _testBio.summary),
      errorMessage: null,
    );
    notifyListeners();
  }

  @override
  Future<void> dispatch(PetEvent event) async {
    if (!canDispatch(event)) {
      return;
    }

    final currentSession = _session;
    final animal = currentSession.animal;
    final bio = currentSession.bio;
    final nextPhase = nextPhaseFor(event, currentSession.phase);
    if (animal == null || bio == null || nextPhase == null) {
      return;
    }

    final reaction = await petAgent.reactStream(
      event: event,
      sessionPhase: currentSession.phase,
      bio: bio,
      animalSpec: animal,
      transcript: currentSession.transcript,
      onChunk: (_) {},
    );
    final updatedTranscript =
        List<PetTranscriptEntry>.of(currentSession.transcript)
          ..add(
            PetTranscriptEntry.user(
              buildPetEventPayload(
                event: event,
                sessionPhase: currentSession.phase,
              ),
            ),
          )
          ..add(PetTranscriptEntry.assistant(reaction.speech));
    _session = currentSession.copyWith(
      phase: nextPhase,
      transcript: updatedTranscript,
      latestReaction: reaction,
      errorMessage: null,
    );
    notifyListeners();
  }

  @override
  Future<void> reset() => bootstrap();
}

class InMemoryPomodoroRepository implements PomodoroRepository {
  final List<SessionRecord> _sessions = [];
  final List<WellnessEvent> _events = [];
  final Map<String, DailyActivitySummary> _summaries = {};
  final DailySummaryService _dailySummaryService = const DailySummaryService();
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

  int eventCountFor(WellnessEventType type) {
    return _events.where((event) => event.type == type).length;
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

    final summary = await loadOrCreateDailySummary(
      dayKey: current.dayKey,
      openedAt: endedAt,
    );
    final updatedSummary = _dailySummaryService.applyEndedSession(
      summary: summary,
      session: ended,
      endedAt: endedAt,
    );
    _summaries[current.dayKey] = updatedSummary;
    if (!_disposed && !_summaryController.isClosed) {
      _summaryController.add(updatedSummary);
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

    final summary = await loadOrCreateDailySummary(
      dayKey: dayKey,
      openedAt: occurredAt,
    );
    final updatedSummary = _dailySummaryService.applyWellnessEvent(
      summary: summary,
      event: event,
    );
    _summaries[dayKey] = updatedSummary;

    if (!_disposed && !_eventsController.isClosed) {
      _eventsController.add(
        _events.where((event) => event.dayKey == dayKey).toList(),
      );
    }
    if (!_disposed && !_summaryController.isClosed) {
      _summaryController.add(updatedSummary);
    }
    return event;
  }

  @override
  Stream<List<WellnessEvent>> watchTodayWellnessEvents(String dayKey) {
    return Stream.multi((controller) {
      controller.add(
        _events
            .where((event) => event.dayKey == dayKey)
            .toList(growable: false),
      );
      final subscription = _eventsController.stream.listen(
        (events) {
          controller.add(
            events
                .where((event) => event.dayKey == dayKey)
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
  Future<DailyActivitySummary> loadOrCreateDailySummary({
    required String dayKey,
    required DateTime openedAt,
  }) async {
    final existing = _summaries[dayKey];
    if (existing != null) {
      return existing;
    }
    final summary = _dailySummaryService.create(
      id: 'summary-${++_idCounter}',
      dayKey: dayKey,
      openedAt: openedAt,
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
    final summary = await loadOrCreateDailySummary(
      dayKey: dayKey,
      openedAt: now,
    );
    final refreshed = _dailySummaryService.aggregate(
      summary: summary,
      sessions: _sessions.where((session) => session.dayKey == dayKey),
      wellnessEvents: _events.where((event) => event.dayKey == dayKey),
      now: now,
    );
    _summaries[dayKey] = refreshed;
    if (!_disposed && !_summaryController.isClosed) {
      _summaryController.add(refreshed);
    }
    return refreshed;
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
    return Stream.multi((controller) {
      final existing = _summaries[dayKey];
      if (existing != null) {
        controller.add(existing);
      }
      final subscription = _summaryController.stream.listen(
        (summary) {
          if (summary.dayKey == dayKey) {
            controller.add(summary);
          }
        },
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> resetCurrentDay({
    required String dayKey,
    required DateTime now,
  }) async {
    _sessions.removeWhere((session) => session.dayKey == dayKey);
    _events.removeWhere((event) => event.dayKey == dayKey);
    _summaries.remove(dayKey);
    await loadOrCreateDailySummary(dayKey: dayKey, openedAt: now);
    _emitSessions();
    _emitActiveSession();
    if (!_disposed && !_eventsController.isClosed) {
      _eventsController.add(
        _events.where((event) => event.dayKey == dayKey).toList(),
      );
    }
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
