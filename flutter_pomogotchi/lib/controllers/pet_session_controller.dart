import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pomogotchi/features/pet/data/pet_sync_repository.dart';
import 'package:pomogotchi/models/pet_bio.dart';
import 'package:pomogotchi/models/pet_event.dart';
import 'package:pomogotchi/models/pet_reaction.dart';
import 'package:pomogotchi/models/pet_session.dart';
import 'package:pomogotchi/models/pet_transcript_entry.dart';
import 'package:pomogotchi/models/session_phase.dart';

abstract class PetSessionController extends ChangeNotifier {
  PetSession get session;

  Future<void> bootstrap();

  Future<void> reset();

  Future<void> dispatch(PetEvent event);

  bool canDispatch(PetEvent event) {
    final currentSession = session;
    if (currentSession.isInitializing ||
        currentSession.isThinking ||
        currentSession.isStreaming) {
      return false;
    }

    if (!currentSession.hasActiveSession) {
      return false;
    }

    return nextPhaseFor(event, currentSession.phase) != null;
  }
}

abstract class SyncedPetSessionController extends PetSessionController {
  SyncedPetSessionController(this.repository);

  final PetSyncRepository repository;

  StreamSubscription<PetSyncSessionRecord?>? _sessionSubscription;
  StreamSubscription<PetSyncEventRecord?>? _activeEventSubscription;
  StreamSubscription<SessionPhase>? _phaseSubscription;

  PetSession _session = PetSession.initial();
  PetSyncSessionRecord? _currentSnapshot;
  PetSyncEventRecord? _currentActiveEvent;
  SessionPhase _currentPhase = SessionPhase.idle;

  bool _isDisposed = false;
  bool _subscriptionsAttached = false;
  bool _isInitializing = false;
  bool _isGeneratingBio = false;
  String? _transientErrorMessage;

  @override
  PetSession get session => _session;

  PetSyncSessionRecord? get currentSnapshot => _currentSnapshot;

  bool get isDisposed => _isDisposed;

  Future<void> attachSyncState() async {
    if (_subscriptionsAttached) {
      return;
    }

    _subscriptionsAttached = true;
    _sessionSubscription = repository.watchCurrentPetSession().listen((
      snapshot,
    ) {
      _currentSnapshot = snapshot;
      if (snapshot != null && _isInitializing) {
        _isInitializing = false;
      }
      _rebuildSession();
    });
    _activeEventSubscription = repository.watchActiveEvent().listen((event) {
      _currentActiveEvent = event;
      _rebuildSession();
    });
    _phaseSubscription = repository.watchCurrentPhase().listen((phase) {
      _currentPhase = phase;
      _rebuildSession();
    });

    await refreshSyncState();
  }

  Future<void> refreshSyncState() async {
    _currentSnapshot = await repository.loadCurrentPetSession();
    _currentActiveEvent = await repository.loadActiveEvent();
    _currentPhase = await repository.loadCurrentPhase();
    if (_currentSnapshot != null && _isInitializing) {
      _isInitializing = false;
    }
    _rebuildSession();
  }

  void setInitializing(bool value) {
    _isInitializing = value;
    _rebuildSession();
  }

  void setGeneratingBio(bool value) {
    _isGeneratingBio = value;
    _rebuildSession();
  }

  void setTransientErrorMessage(String? errorMessage) {
    _transientErrorMessage = errorMessage;
    _rebuildSession();
  }

  void _rebuildSession() {
    if (_isDisposed) {
      return;
    }

    final snapshot = _currentSnapshot;
    final latestSpeech = snapshot?.latestSpeech.trim() ?? '';
    final latestReaction = latestSpeech.isEmpty
        ? null
        : PetReaction(speech: latestSpeech);

    _session = PetSession(
      animal: snapshot?.animalSpec,
      bio: snapshot == null
          ? null
          : PetBio(name: snapshot.bioName, summary: snapshot.bioSummary),
      phase: _currentPhase,
      transcript: const <PetTranscriptEntry>[],
      latestReaction: latestReaction,
      pendingSpeech: '',
      isInitializing: _isInitializing && snapshot == null,
      isGeneratingBio: _isGeneratingBio,
      isThinking:
          _currentActiveEvent?.status == PetEventStatus.pending ||
          _currentActiveEvent?.status == PetEventStatus.processing,
      isStreaming: false,
      errorMessage: _transientErrorMessage ?? snapshot?.lastError,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_sessionSubscription?.cancel());
    unawaited(_activeEventSubscription?.cancel());
    unawaited(_phaseSubscription?.cancel());
    super.dispose();
  }
}

SessionPhase? nextPhaseFor(PetEvent event, SessionPhase currentPhase) {
  return switch (event) {
    PetEvent.startFocusSession =>
      currentPhase == SessionPhase.idle ? SessionPhase.focusInProgress : null,
    PetEvent.completeFocusSession || PetEvent.stopFocusSessionEarly =>
      currentPhase == SessionPhase.focusInProgress ? SessionPhase.idle : null,
    PetEvent.startBreak =>
      currentPhase == SessionPhase.idle ? SessionPhase.breakInProgress : null,
    PetEvent.completeBreak || PetEvent.stopBreakEarly =>
      currentPhase == SessionPhase.breakInProgress ? SessionPhase.idle : null,
    PetEvent.petPet ||
    PetEvent.drinkWater ||
    PetEvent.moveOrStretch => currentPhase,
  };
}

String friendlyPetError(Object error) {
  return error.toString().replaceFirst('Exception: ', '').trim();
}
