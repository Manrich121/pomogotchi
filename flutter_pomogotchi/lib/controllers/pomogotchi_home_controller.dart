import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pomogotchi/controllers/pet_session_controller.dart';
import 'package:pomogotchi/features/pomodoro/application/pomodoro_controller.dart';
import 'package:pomogotchi/features/pomodoro/application/pomodoro_view_state.dart';
import 'package:pomogotchi/features/pomodoro/domain/models/session_record.dart';
import 'package:pomogotchi/models/pet_event.dart';
import 'package:pomogotchi/models/pet_session.dart';

class PomogotchiHomeController extends ChangeNotifier {
  PomogotchiHomeController({
    required this.pomodoroController,
    required this.petSessionController,
    this.disposeChildren = true,
  }) {
    pomodoroController.addListener(_handlePomodoroChanged);
    petSessionController.addListener(_handlePetChanged);
    _lastActiveSessionId = pomodoroController.state.activeSession?.id;
  }

  final PomodoroController pomodoroController;
  final PetSessionController petSessionController;
  final bool disposeChildren;

  bool _isInitialized = false;
  bool _isDisposed = false;
  String? _lastActiveSessionId;

  PomodoroViewState get pomodoroState => pomodoroController.state;
  PetSession get petSession => petSessionController.session;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    await Future.wait([
      pomodoroController.initialize(),
      petSessionController.bootstrap(),
    ]);
    _lastActiveSessionId = pomodoroController.state.activeSession?.id;
    _isInitialized = true;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  bool get canStartFocus =>
      pomodoroState.status == PomodoroScreenStatus.idle &&
      petSession.hasActiveSession &&
      !petSession.isBusy;

  bool get canLogHydration =>
      pomodoroState.status != PomodoroScreenStatus.loading &&
      pomodoroState.status != PomodoroScreenStatus.error &&
      petSession.hasActiveSession;

  bool get canLogMovement => canLogHydration;

  bool get canPet => petSessionController.canDispatch(PetEvent.petPet);

  Future<void> startFocus() async {
    await pomodoroController.startFocusSession();
    await petSessionController.dispatch(PetEvent.startFocusSession);
  }

  Future<void> pauseSession() async {
    await pomodoroController.pauseSession();
  }

  Future<void> resumeSession() async {
    await pomodoroController.resumeSession();
  }

  Future<void> stopSession() async {
    final activeSession = pomodoroState.activeSession;
    if (activeSession == null) {
      return;
    }

    await pomodoroController.stopSession();
    if (activeSession.type == SessionType.focus) {
      await petSessionController.dispatch(PetEvent.stopFocusSessionEarly);
    } else {
      await petSessionController.dispatch(PetEvent.stopBreakEarly);
    }
  }

  Future<void> startBreak() async {
    await pomodoroController.startBreakSession();
    await petSessionController.dispatch(PetEvent.startBreak);
  }

  Future<void> logHydration() async {
    await pomodoroController.logHydration();
    await petSessionController.dispatch(PetEvent.drinkWater);
  }

  Future<void> logMovement() async {
    await pomodoroController.logMovement();
    await petSessionController.dispatch(PetEvent.moveOrStretch);
  }

  Future<void> petPet() async {
    await petSessionController.dispatch(PetEvent.petPet);
  }

  Future<void> backToIdle() async {
    pomodoroController.resetCompletionPrompt();
  }

  Future<void> resetAll() async {
    await Future.wait([
      pomodoroController.resetCurrentDay(),
      petSessionController.reset(),
    ]);
  }

  void _handlePomodoroChanged() {
    final nextState = pomodoroController.state;
    final completionEvent = _completionEventForTransition(
      previousActiveSessionId: _lastActiveSessionId,
      nextState: nextState,
    );
    _lastActiveSessionId = nextState.activeSession?.id;
    if (!_isDisposed) {
      notifyListeners();
    }
    if (completionEvent != null) {
      unawaited(petSessionController.dispatch(completionEvent));
    }
  }

  PetEvent? _completionEventForTransition({
    required String? previousActiveSessionId,
    required PomodoroViewState nextState,
  }) {
    if (previousActiveSessionId == null || nextState.activeSession != null) {
      return null;
    }

    return switch (nextState.status) {
      PomodoroScreenStatus.focusCompleted => PetEvent.completeFocusSession,
      PomodoroScreenStatus.breakCompleted => PetEvent.completeBreak,
      _ => null,
    };
  }

  void _handlePetChanged() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    pomodoroController.removeListener(_handlePomodoroChanged);
    petSessionController.removeListener(_handlePetChanged);
    if (disposeChildren) {
      pomodoroController.dispose();
      petSessionController.dispose();
    }
    super.dispose();
  }
}
