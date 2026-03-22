import 'package:flutter_test/flutter_test.dart';
import 'package:pomogotchi/controllers/pomogotchi_home_controller.dart';
import 'package:pomogotchi/features/pomodoro/application/pomodoro_controller.dart';
import 'package:pomogotchi/features/pomodoro/application/pomodoro_view_state.dart';
import 'package:pomogotchi/features/pomodoro/domain/models/wellness_event.dart';
import 'package:pomogotchi/models/pet_event.dart';
import 'package:pomogotchi/models/session_phase.dart';

import '../support/pomogotchi_test_stubs.dart';

void main() {
  late InMemoryPomodoroRepository repository;
  late MutableClock clock;
  late FakeLifecycleService lifecycle;
  late FakePetAgent petAgent;
  late PomogotchiHomeController controller;

  setUp(() async {
    repository = InMemoryPomodoroRepository();
    clock = MutableClock(DateTime.utc(2026, 1, 1, 9));
    lifecycle = FakeLifecycleService();
    petAgent = FakePetAgent();
    controller = PomogotchiHomeController(
      pomodoroController: PomodoroController(
        repository: repository,
        clock: clock,
        lifecycleService: lifecycle,
      ),
      petSessionController: buildTestPetSessionController(petAgent: petAgent),
    );
    await controller.initialize();
  });

  tearDown(() async {
    controller.dispose();
    await repository.dispose();
    await lifecycle.dispose();
  });

  test('start focus updates timer and pet together', () async {
    await controller.startFocus();

    expect(controller.pomodoroState.status, PomodoroScreenStatus.focusActive);
    expect(controller.petSession.phase, SessionPhase.focusInProgress);
    expect(petAgent.events, [PetEvent.startFocusSession]);
  });

  test('stop focus early keeps timer and pet in sync', () async {
    await controller.startFocus();
    await controller.stopSession();

    expect(controller.pomodoroState.status, PomodoroScreenStatus.idle);
    expect(controller.petSession.phase, SessionPhase.idle);
    expect(petAgent.events, [
      PetEvent.startFocusSession,
      PetEvent.stopFocusSessionEarly,
    ]);
  });

  test('hydration and movement logging trigger both timer and pet paths', () async {
    await controller.logHydration();
    await controller.logMovement();

    expect(repository.eventCountFor(WellnessEventType.hydration), 1);
    expect(repository.eventCountFor(WellnessEventType.movement), 1);
    expect(petAgent.events, [
      PetEvent.drinkWater,
      PetEvent.moveOrStretch,
    ]);
  });

  test('resetAll clears today summary data and keeps a bootstrapped pet', () async {
    await controller.logHydration();
    expect(controller.pomodoroState.dailySummary?.hydrationCount, 1);

    await controller.resetAll();

    expect(controller.pomodoroState.status, PomodoroScreenStatus.idle);
    expect(controller.pomodoroState.dailySummary?.hydrationCount, 0);
    expect(controller.petSession.hasActiveSession, isTrue);
  });
}
