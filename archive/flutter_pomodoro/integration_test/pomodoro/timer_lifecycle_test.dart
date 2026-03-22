import 'package:flutter/material.dart';
import 'package:flutter_pomodoro/features/pomodoro/application/pomodoro_controller.dart';
import 'package:flutter_pomodoro/features/pomodoro/presentation/screens/pomodoro_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../test/support/pomodoro_test_stubs.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('focus-to-break lifecycle and restore flow', (tester) async {
    final repository = InMemoryPomodoroRepository();
    final clock = MutableClock(DateTime.utc(2026, 1, 1, 9));
    final lifecycle = FakeLifecycleService();
    final controller = PomodoroController(
      repository: repository,
      clock: clock,
      lifecycleService: lifecycle,
    );
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(home: PomodoroScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start focus'), findsOneWidget);
    await tester.tap(find.text('Start focus'));
    await tester.pump();
    expect(find.text('Focus session'), findsOneWidget);

    lifecycle.emit(AppLifecycleState.paused);
    lifecycle.emit(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Focus session'), findsOneWidget);

    clock.advance(const Duration(minutes: 40, seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Start break'), findsOneWidget);
    await tester.tap(find.text('Start break'));
    await tester.pump();
    expect(find.text('Break session'), findsOneWidget);

    controller.dispose();
    await repository.dispose();
    await lifecycle.dispose();
  });
}
