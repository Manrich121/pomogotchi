import 'package:flutter/material.dart';
import 'package:flutter_pomodoro/features/pomodoro/application/pomodoro_view_state.dart';

class TimerHeader extends StatelessWidget {
  const TimerHeader({
    super.key,
    required this.status,
    required this.remainingSeconds,
  });

  final PomodoroScreenStatus status;
  final int? remainingSeconds;

  @override
  Widget build(BuildContext context) {
    final label = _labelForStatus(status);
    final time = _formatDuration(remainingSeconds ?? _defaultForStatus(status));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Semantics(
          label: '$label: $time remaining',
          child: Text(time, style: Theme.of(context).textTheme.displayMedium),
        ),
      ],
    );
  }

  String _labelForStatus(PomodoroScreenStatus status) {
    return switch (status) {
      PomodoroScreenStatus.focusActive => 'Focus session',
      PomodoroScreenStatus.focusPaused => 'Focus paused',
      PomodoroScreenStatus.breakActive => 'Break session',
      PomodoroScreenStatus.breakPaused => 'Break paused',
      PomodoroScreenStatus.focusCompleted => 'Focus complete 🎉',
      PomodoroScreenStatus.breakCompleted => 'Break complete 🎉',
      PomodoroScreenStatus.loading => 'Loading',
      PomodoroScreenStatus.error => 'Session error',
      PomodoroScreenStatus.idle => 'Ready to focus',
    };
  }

  int _defaultForStatus(PomodoroScreenStatus status) {
    return switch (status) {
      PomodoroScreenStatus.focusCompleted => 0,
      PomodoroScreenStatus.breakActive ||
      PomodoroScreenStatus.breakPaused => 10 * 60,
      PomodoroScreenStatus.breakCompleted => 0,
      _ => 40 * 60,
    };
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
