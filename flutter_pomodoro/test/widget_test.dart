import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_pomodoro/app/app.dart';

import 'support/pomodoro_test_stubs.dart';

void main() {
  testWidgets('App bootstrap smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      PomogotchiApp(databaseOwner: PendingPomodoroDatabaseOwner()),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
