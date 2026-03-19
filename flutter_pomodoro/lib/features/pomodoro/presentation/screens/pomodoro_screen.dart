import 'package:flutter/material.dart';
import 'package:flutter_pomodoro/features/pomodoro/application/pomodoro_controller.dart';
import 'package:flutter_pomodoro/features/pomodoro/application/pomodoro_view_state.dart';
import 'package:flutter_pomodoro/features/pomodoro/presentation/widgets/completion_prompt.dart';
import 'package:flutter_pomodoro/features/pomodoro/presentation/widgets/daily_summary_panel.dart';
import 'package:flutter_pomodoro/features/pomodoro/presentation/widgets/session_action_bar.dart';
import 'package:flutter_pomodoro/features/pomodoro/presentation/widgets/timer_header.dart';
import 'package:flutter_pomodoro/features/pomodoro/presentation/widgets/wellness_actions.dart';

class PomodoroScreen extends StatelessWidget {
  const PomodoroScreen({super.key, required this.controller, this.onSignOut});

  final PomodoroController controller;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final showInteractiveContent =
            state.status != PomodoroScreenStatus.loading &&
            state.status != PomodoroScreenStatus.error;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Pomogotchi'),
            actions: [
              if (onSignOut != null)
                IconButton(
                  onPressed: onSignOut,
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout),
                ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                showInteractiveContent
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TimerHeader(
                              status: state.status,
                              remainingSeconds: state.remainingSeconds,
                            ),
                          ),
                          const SizedBox(width: 16),
                          WellnessActions(
                            compact: true,
                            onLogHydration: controller.logHydration,
                            onLogMovement: controller.logMovement,
                          ),
                        ],
                      )
                    : TimerHeader(
                        status: state.status,
                        remainingSeconds: state.remainingSeconds,
                      ),
                const SizedBox(height: 16),
                SessionActionBar(status: state.status, controller: controller),
                const SizedBox(height: 16),
                CompletionPrompt(status: state.status, controller: controller),
                const SizedBox(height: 16),
                if (state.dailySummary != null && showInteractiveContent) ...[
                  DailySummaryPanel(summary: state.dailySummary!),
                  const SizedBox(height: 16),
                ],
                _buildStateHint(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStateHint(BuildContext context, PomodoroViewState state) {
    if (state.status == PomodoroScreenStatus.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.status == PomodoroScreenStatus.error) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(state.errorMessage ?? 'Unable to load Pomodoro data'),
          const SizedBox(height: 12),
          FilledButton(onPressed: controller.retry, child: const Text('Retry')),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
