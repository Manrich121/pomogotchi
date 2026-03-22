import 'package:flutter_pomodoro/features/pomodoro/application/pomodoro_controller.dart';
import 'package:flutter_pomodoro/features/pomodoro/application/pomodoro_view_state.dart';
import 'package:flutter_pomodoro/features/pomodoro/domain/models/session_record.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pomodoro_test_stubs.dart';

void main() {
  late InMemoryPomodoroRepository repository;
  late MutableClock clock;
  late FakeLifecycleService lifecycle;
  late PomodoroController controller;

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

  test('reacts to a remotely synced active session', () async {
    expect(controller.state.status, PomodoroScreenStatus.idle);
    expect(controller.state.activeSession, isNull);

    repository.syncRemoteSession(
      SessionRecord(
        id: 'remote-focus',
        dayKey: '2026-01-01',
        type: SessionType.focus,
        plannedDurationSeconds: 2400,
        state: SessionLifecycleState.active,
        startedAt: DateTime.utc(2026, 1, 1, 9),
        lastResumedAt: DateTime.utc(2026, 1, 1, 9),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.activeSession?.id, 'remote-focus');
    expect(controller.state.status, PomodoroScreenStatus.focusActive);
    expect(controller.state.remainingSeconds, 2400);
  });
}
