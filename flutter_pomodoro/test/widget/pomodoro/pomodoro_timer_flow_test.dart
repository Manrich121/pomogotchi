import 'package:flutter/material.dart';
import 'package:flutter_pomodoro/features/pomodoro/application/pomodoro_controller.dart';
import 'package:flutter_pomodoro/features/pomodoro/domain/models/session_record.dart';
import 'package:flutter_pomodoro/features/pomodoro/presentation/screens/pomodoro_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pomodoro_test_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryPomodoroRepository repository;
  late MutableClock clock;
  late FakeLifecycleService lifecycle;
  late PomodoroController controller;

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: PomodoroScreen(controller: controller)),
    );
    await tester.pump();
  }

  setUp(() async {
    repository = InMemoryPomodoroRepository();
    clock = MutableClock(DateTime.utc(2026, 1, 1, 9));
    lifecycle = FakeLifecycleService();
    controller = PomodoroController(
      repository: repository,
      clock: clock,
      lifecycleService: lifecycle,
    );
    await controller.initialize();
  });

  tearDown(() async {
    controller.dispose();
    await repository.dispose();
    await lifecycle.dispose();
  });

  testWidgets('idle state renders start action and 40:00 timer', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Ready to focus'), findsOneWidget);
    expect(find.text('40:00'), findsOneWidget);
    expect(find.text('Start focus'), findsOneWidget);
  });

  testWidgets('running and paused states show expected actions', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Start focus'));
    await tester.pump();

    expect(find.text('Focus session'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pump();

    expect(find.text('Focus paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
  });

  testWidgets('focus completion prompt can start break', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Start focus'));
    await tester.pump();

    clock.advance(const Duration(minutes: 40, seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Focus complete 🎉'), findsOneWidget);
    expect(find.text('Start break'), findsOneWidget);

    await tester.tap(find.text('Start break'));
    await tester.pump();

    expect(find.text('Break session'), findsOneWidget);
    await controller.stopSession();
    await tester.pump();
  });

  testWidgets('break-completed state indicator is shown', (tester) async {
    controller.dispose();
    await repository.dispose();
    await lifecycle.dispose();

    repository = InMemoryPomodoroRepository();
    clock = MutableClock(DateTime.utc(2026, 1, 1, 9));
    lifecycle = FakeLifecycleService();
    final startedAt = DateTime.utc(2026, 1, 1, 8, 0, 0);
    repository.seedSession(
      SessionRecord(
        id: 'ended-break',
        dayKey: '2026-01-01',
        type: SessionType.breakTime,
        plannedDurationSeconds: 600,
        state: SessionLifecycleState.ended,
        outcome: SessionOutcome.completed,
        startedAt: startedAt,
        lastResumedAt: startedAt,
        endedAt: startedAt.add(const Duration(minutes: 10)),
      ),
    );
    controller = PomodoroController(
      repository: repository,
      clock: clock,
      lifecycleService: lifecycle,
    );
    await controller.initialize();

    await pumpScreen(tester);
    await tester.pump();

    expect(find.textContaining('Break completed'), findsOneWidget);
    expect(find.text('Back to idle'), findsOneWidget);
  });

  testWidgets('golden idle state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScreen(tester);
    await expectLater(
      find.byType(PomodoroScreen),
      matchesGoldenFile('goldens/pomodoro_idle.png'),
    );
  });

  testWidgets('golden focus-active state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScreen(tester);
    await tester.tap(find.text('Start focus'));
    await tester.pump();

    await expectLater(
      find.byType(PomodoroScreen),
      matchesGoldenFile('goldens/pomodoro_focus_active.png'),
    );

    await controller.stopSession();
    await tester.pump();
  });
}
