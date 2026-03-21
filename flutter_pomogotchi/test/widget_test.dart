import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomogotchi/controllers/pomogotchi_home_controller.dart';
import 'package:pomogotchi/features/pomodoro/application/pomodoro_controller.dart';
import 'package:pomogotchi/pomogotchi_app.dart';

import 'support/pomogotchi_test_stubs.dart';

void main() {
  testWidgets('renders the merged Pomogotchi home shell', (tester) async {
    final repository = InMemoryPomodoroRepository();
    final lifecycle = FakeLifecycleService();
    final controller = PomogotchiHomeController(
      pomodoroController: PomodoroController(
        repository: repository,
        clock: MutableClock(DateTime.utc(2026, 1, 1, 9)),
        lifecycleService: lifecycle,
      ),
      petSessionController: buildTestPetSessionController(),
    );
    await controller.initialize();

    await tester.pumpWidget(PomogotchiApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Bernie'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('timer-card')),
        matching: find.text('Start focus'),
      ),
      findsOneWidget,
    );
    expect(find.text('40:00'), findsOneWidget);
    expect(find.text('PoC controls'), findsOneWidget);

    controller.dispose();
    await repository.dispose();
    await lifecycle.dispose();
  });
}
