import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomogotchi/controllers/pomogotchi_home_controller.dart';
import 'package:pomogotchi/features/pomodoro/application/pomodoro_controller.dart';
import 'package:pomogotchi/features/pomodoro/application/pomodoro_view_state.dart';
import 'package:pomogotchi/pomogotchi_app.dart';

import '../../support/pomogotchi_test_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryPomodoroRepository repository;
  late MutableClock clock;
  late FakeLifecycleService lifecycle;
  late FakePetAgent petAgent;
  late PomogotchiHomeController controller;

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(PomogotchiApp(controller: controller));
    await tester.pump();
  }

  String textForKey(WidgetTester tester, Key key) {
    return tester.widget<Text>(find.byKey(key)).data ?? '';
  }

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

  testWidgets('idle state renders pet and timer card', (tester) async {
    await pumpApp(tester);

    expect(find.text('Bernie'), findsOneWidget);
    expect(find.text('40:00'), findsOneWidget);
    expect(find.text('Start focus'), findsWidgets);
    expect(find.byKey(const Key('daily-summary-focus-count')), findsOneWidget);
  });

  testWidgets('start focus turns timer card into a live focus session', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('timer-card')));
    await tester.pumpAndSettle();

    expect(controller.pomodoroState.status, PomodoroScreenStatus.focusActive);
    expect(find.text('Focus session'), findsWidgets);
    expect(find.byKey(const Key('session-pause')), findsOneWidget);
    expect(find.byKey(const Key('session-stop')), findsOneWidget);

    await controller.stopSession();
    await tester.pumpAndSettle();
  });

  testWidgets('focus completion shows break CTA and updates summary', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('timer-card')));
    await tester.pumpAndSettle();

    clock.advance(const Duration(minutes: 40, seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(controller.pomodoroState.status, PomodoroScreenStatus.focusCompleted);
    expect(controller.pomodoroState.dailySummary?.endedFocusCount, 1);
    expect(find.byKey(const Key('session-start-break')), findsOneWidget);
    expect(find.text('Focus complete'), findsWidgets);
    expect(textForKey(tester, const Key('daily-summary-focus-count')), '1');
  });

  testWidgets('hydration and movement actions update summary counts', (
    tester,
  ) async {
    await pumpApp(tester);

    await controller.logHydration();
    await controller.logMovement();
    await tester.pumpAndSettle();
    await tester.pump();

    expect(controller.pomodoroState.dailySummary?.hydrationCount, 1);
    expect(controller.pomodoroState.dailySummary?.movementCount, 1);
    expect(textForKey(tester, const Key('daily-summary-hydration-count')), '1');
    expect(textForKey(tester, const Key('daily-summary-movement-count')), '1');
  });

}
