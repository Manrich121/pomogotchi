import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomogotchi/controllers/pomogotchi_home_controller.dart';
import 'package:pomogotchi/features/auth/presentation/magic_link_sign_in_screen.dart';
import 'package:pomogotchi/features/pomodoro/application/pomodoro_controller.dart';
import 'package:pomogotchi/features/pomodoro/data/pomodoro_sync.dart';
import 'package:pomogotchi/pomogotchi_app.dart';

import 'support/pomogotchi_test_stubs.dart';
import 'support/pomogotchi_sync_test_stubs.dart';

void main() {
  testWidgets('shows magic link sign-in screen when logged out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      PomogotchiApp(authClient: FakePomodoroAuthClient()),
    );
    await tester.pump();

    expect(find.text('Sign in with email'), findsOneWidget);
    expect(find.text('Send magic link'), findsOneWidget);
    expect(find.text('Verify code'), findsNothing);
  });

  testWidgets('shows bootstrap spinner when already signed in', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      PomogotchiApp(
        authClient: FakePomodoroAuthClient(
          currentSession: const PomodoroAuthSession(
            accessToken: 'token',
            userId: 'user-1',
          ),
        ),
        databaseOwner: PendingPomodoroDatabaseOwner(),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('submits email code verification from the sign-in screen', (
    WidgetTester tester,
  ) async {
    var requestCalls = 0;
    String? submittedEmail;
    String? submittedCode;

    await tester.pumpWidget(
      MaterialApp(
        home: MagicLinkSignInScreen(
          onRequestMagicLink: (_) async {
            requestCalls += 1;
          },
          onVerifyEmailCode: (email, code) async {
            submittedEmail = email;
            submittedCode = code;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'user@test.com');
    await tester.tap(find.text('Send magic link'));
    await tester.pump();

    expect(requestCalls, 1);
    expect(find.text('Verify code'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, '924252');
    await tester.ensureVisible(find.text('Verify code'));
    await tester.tap(find.text('Verify code'));
    await tester.pump();

    expect(submittedEmail, 'user@test.com');
    expect(submittedCode, '924252');
  });

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
