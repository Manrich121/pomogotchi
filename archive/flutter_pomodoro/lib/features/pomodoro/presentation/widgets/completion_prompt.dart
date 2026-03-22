import 'package:flutter/material.dart';
import 'package:flutter_pomodoro/features/pomodoro/application/pomodoro_controller.dart';
import 'package:flutter_pomodoro/features/pomodoro/application/pomodoro_view_state.dart';

class CompletionPrompt extends StatelessWidget {
  const CompletionPrompt({
    super.key,
    required this.status,
    required this.controller,
  });

  final PomodoroScreenStatus status;
  final PomodoroController controller;

  @override
  Widget build(BuildContext context) {
    if (status != PomodoroScreenStatus.focusCompleted &&
        status != PomodoroScreenStatus.breakCompleted) {
      return const SizedBox.shrink();
    }

    if (status == PomodoroScreenStatus.focusCompleted) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Focus complete 🎉',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: controller.startBreakSession,
                    child: const Text('Start break'),
                  ),
                  OutlinedButton(
                    onPressed: controller.resetCompletionPrompt,
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Break completed. Ready for the next focus session.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
