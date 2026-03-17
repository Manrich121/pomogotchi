import 'package:flutter/material.dart';
import 'package:flutter_pomodoro/features/pomodoro/application/pomodoro_controller.dart';
import 'package:flutter_pomodoro/features/pomodoro/application/pomodoro_view_state.dart';

const double _actionGroupWidth = 280;

class SessionActionBar extends StatelessWidget {
  const SessionActionBar({
    super.key,
    required this.status,
    required this.controller,
  });

  final PomodoroScreenStatus status;
  final PomodoroController controller;

  @override
  Widget build(BuildContext context) {
    if (status == PomodoroScreenStatus.loading) {
      return const SizedBox.shrink();
    }

    if (status == PomodoroScreenStatus.idle) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: _actionGroupWidth,
          child: FilledButton(
            onPressed: controller.startFocusSession,
            child: const Text('Start focus'),
          ),
        ),
      );
    }

    if (status == PomodoroScreenStatus.focusActive ||
        status == PomodoroScreenStatus.breakActive) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: _actionGroupWidth,
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: controller.pauseSession,
                  child: const Text('Pause'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.stopSession,
                  child: const Text('Stop'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (status == PomodoroScreenStatus.focusPaused ||
        status == PomodoroScreenStatus.breakPaused) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: _actionGroupWidth,
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: controller.resumeSession,
                  child: const Text('Resume'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.stopSession,
                  child: const Text('Stop'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (status == PomodoroScreenStatus.breakCompleted) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: _actionGroupWidth,
          child: FilledButton(
            onPressed: controller.resetCompletionPrompt,
            child: const Text('Back to idle'),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
