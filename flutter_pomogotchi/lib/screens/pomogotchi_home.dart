import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pomogotchi/controllers/pomogotchi_home_controller.dart';
import 'package:pomogotchi/features/pomodoro/application/pomodoro_view_state.dart';
import 'package:pomogotchi/models/pet_session.dart';

class PomogotchiHome extends StatelessWidget {
  const PomogotchiHome({super.key, required this.controller, this.onSignOut});

  final PomogotchiHomeController controller;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final petSession = controller.petSession;
        final pomodoroState = controller.pomodoroState;

        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF7F1DD), Color(0xFFE8E1C6)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFCF4),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: const Color(0xFF1F1A17),
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SessionHeader(session: petSession),
                                const SizedBox(height: 18),
                                _TopActionRow(controller: controller),
                                const SizedBox(height: 18),
                                _SpeechBubble(
                                  speech: _displayedSpeech(
                                    session: petSession,
                                    pomodoroState: pomodoroState,
                                  ),
                                  maxLines: _speechBubbleMaxLines(
                                    session: petSession,
                                  ),
                                  isPending:
                                      petSession.isThinking ||
                                      petSession.isStreaming,
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: max(320, constraints.maxHeight - 380),
                                  child: _PetStage(
                                    controller: controller,
                                    session: petSession,
                                  ),
                                ),
                                if (pomodoroState.errorMessage != null) ...[
                                  const SizedBox(height: 12),
                                  _ErrorBanner(
                                    message: pomodoroState.errorMessage!,
                                  ),
                                ],
                                if (petSession.errorMessage != null) ...[
                                  const SizedBox(height: 12),
                                  _ErrorBanner(
                                    message: petSession.errorMessage!,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                _DailySummaryPanel(controller: controller),
                                const SizedBox(height: 12),
                                _TestPanel(
                                  controller: controller,
                                  onSignOut: onSignOut,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _displayedSpeech({
    required PetSession session,
    required PomodoroViewState pomodoroState,
  }) {
    if (session.pendingSpeech.trim().isNotEmpty) {
      return session.pendingSpeech.trim();
    }

    if (session.latestReaction != null) {
      return session.latestReaction!.speech;
    }

    if (pomodoroState.isLoading || session.isGeneratingBio) {
      return 'Warming up your Pomogotchi and restoring today\'s routine...';
    }

    if (session.isInitializing) {
      return 'Waiting for your Pomogotchi to sync from Mac...';
    }

    if (session.errorMessage != null) {
      return 'Pomogotchi hit a snag, but your timer data is still safe.';
    }

    return 'Reset to spin up a fresh Pomogotchi session.';
  }

  int? _speechBubbleMaxLines({required PetSession session}) {
    final bio = session.bio;
    final latestReaction = session.latestReaction;
    final isInitialBioSummary =
        bio != null &&
        latestReaction != null &&
        session.transcript.isEmpty &&
        session.pendingSpeech.trim().isEmpty &&
        latestReaction.speech == bio.summary;

    return isInitialBioSummary ? 2 : null;
  }
}

class _TopActionRow extends StatelessWidget {
  const _TopActionRow({required this.controller});

  final PomogotchiHomeController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: _TimerCard(controller: controller)),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PrimaryActionButton(
                      label: null,
                      icon: Icons.local_drink_outlined,
                      onPressed: controller.canLogHydration
                          ? controller.logHydration
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PrimaryActionButton(
                      label: null,
                      icon: Icons.accessibility_new_rounded,
                      onPressed: controller.canLogMovement
                          ? controller.logMovement
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SessionActionDock(controller: controller),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.controller});

  final PomogotchiHomeController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.pomodoroState;
    final status = state.status;
    final canStart = controller.canStartFocus;
    final isIdle = status == PomodoroScreenStatus.idle;

    return GestureDetector(
      onTap: canStart ? controller.startFocus : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: isIdle && !canStart ? 0.45 : 1,
        child: Container(
          key: const Key('timer-card'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1F1A17), width: 2.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _iconForStatus(status),
                    color: const Color(0xFF1F1A17),
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _labelForStatus(status),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _formatDuration(
                  state.remainingSeconds ?? _defaultSecondsForStatus(status),
                ),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForStatus(PomodoroScreenStatus status) {
    return switch (status) {
      PomodoroScreenStatus.focusActive => Icons.timer_rounded,
      PomodoroScreenStatus.focusPaused => Icons.pause_circle_outline_rounded,
      PomodoroScreenStatus.breakActive => Icons.free_breakfast_rounded,
      PomodoroScreenStatus.breakPaused => Icons.pause_circle_outline_rounded,
      PomodoroScreenStatus.focusCompleted => Icons.check_circle_outline_rounded,
      PomodoroScreenStatus.breakCompleted => Icons.check_circle_outline_rounded,
      PomodoroScreenStatus.loading => Icons.hourglass_bottom_rounded,
      PomodoroScreenStatus.error => Icons.warning_amber_rounded,
      PomodoroScreenStatus.idle => Icons.play_arrow_rounded,
    };
  }

  String _labelForStatus(PomodoroScreenStatus status) {
    return switch (status) {
      PomodoroScreenStatus.focusActive => 'Focus session',
      PomodoroScreenStatus.focusPaused => 'Focus paused',
      PomodoroScreenStatus.breakActive => 'Break session',
      PomodoroScreenStatus.breakPaused => 'Break paused',
      PomodoroScreenStatus.focusCompleted => 'Focus complete',
      PomodoroScreenStatus.breakCompleted => 'Break complete',
      PomodoroScreenStatus.loading => 'Loading timer',
      PomodoroScreenStatus.error => 'Timer error',
      PomodoroScreenStatus.idle => 'Start focus',
    };
  }

  int _defaultSecondsForStatus(PomodoroScreenStatus status) {
    return switch (status) {
      PomodoroScreenStatus.breakActive ||
      PomodoroScreenStatus.breakPaused => 10 * 60,
      PomodoroScreenStatus.focusCompleted ||
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

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session});

  final PetSession session;

  @override
  Widget build(BuildContext context) {
    final name =
        session.bio?.name ??
        (session.isInitializing ? 'Waiting for Mac' : 'Summoning pet');

    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        name,
        textAlign: TextAlign.left,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
        ),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({
    required this.speech,
    required this.isPending,
    this.maxLines,
  });

  final String speech;
  final bool isPending;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1F1A17), width: 3),
      ),
      child: Column(
        children: [
          Text(
            speech,
            textAlign: TextAlign.center,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PetStage extends StatelessWidget {
  const _PetStage({required this.controller, required this.session});

  final PomogotchiHomeController controller;
  final PetSession session;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: session.animal == null
              ? const _EmptyPetStage()
              : Transform.translate(
                  offset: const Offset(0, -60),
                  child: _StageImage(
                    assetPath: session.animal!.artAssetPath,
                    width: 185,
                  ),
                ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: _HeartButton(
            enabled: controller.canPet,
            onPressed: controller.petPet,
          ),
        ),
      ],
    );
  }
}

class _SessionActionDock extends StatelessWidget {
  const _SessionActionDock({required this.controller});

  final PomogotchiHomeController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.pomodoroState.status;
    final buttons = switch (status) {
      PomodoroScreenStatus.focusActive || PomodoroScreenStatus.breakActive => [
        _DockButtonData(
          key: const Key('session-pause'),
          label: 'Pause',
          onPressed: controller.pauseSession,
        ),
        _DockButtonData(
          key: const Key('session-stop'),
          label: 'Stop',
          onPressed: controller.stopSession,
          outlined: true,
        ),
      ],
      PomodoroScreenStatus.focusPaused || PomodoroScreenStatus.breakPaused => [
        _DockButtonData(
          key: const Key('session-resume'),
          label: 'Resume',
          onPressed: controller.resumeSession,
        ),
        _DockButtonData(
          key: const Key('session-stop'),
          label: 'Stop',
          onPressed: controller.stopSession,
          outlined: true,
        ),
      ],
      PomodoroScreenStatus.focusCompleted => [
        _DockButtonData(
          key: const Key('session-start-break'),
          label: 'Start break',
          onPressed: controller.startBreak,
        ),
        _DockButtonData(
          key: const Key('session-reset-completion'),
          label: 'Reset',
          onPressed: controller.backToIdle,
          outlined: true,
        ),
      ],
      PomodoroScreenStatus.breakCompleted => [
        _DockButtonData(
          key: const Key('session-back-idle'),
          label: 'Back to idle',
          onPressed: controller.backToIdle,
        ),
      ],
      _ => const <_DockButtonData>[],
    };

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1F1A17), width: 2),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final button in buttons)
            button.outlined
                ? OutlinedButton(
                    key: button.key,
                    onPressed: button.onPressed,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF211A15),
                      side: const BorderSide(color: Color(0xFF1F1A17)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(button.label),
                  )
                : FilledButton(
                    key: button.key,
                    onPressed: button.onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2F5130),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(button.label),
                  ),
        ],
      ),
    );
  }
}

class _DockButtonData {
  const _DockButtonData({
    required this.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final Key key;
  final String label;
  final VoidCallback onPressed;
  final bool outlined;
}

class _DailySummaryPanel extends StatelessWidget {
  const _DailySummaryPanel({required this.controller});

  final PomogotchiHomeController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.pomodoroState.dailySummary;
    if (summary == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E8D0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F1A17), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryMetric(
                label: 'Focus ended',
                value: summary.endedFocusCount,
                valueKey: const Key('daily-summary-focus-count'),
              ),
              _SummaryMetric(
                label: 'Break ended',
                value: summary.endedBreakCount,
                valueKey: const Key('daily-summary-break-count'),
              ),
              _SummaryMetric(
                label: 'Hydration',
                value: summary.hydrationCount,
                valueKey: const Key('daily-summary-hydration-count'),
              ),
              _SummaryMetric(
                label: 'Movement',
                value: summary.movementCount,
                valueKey: const Key('daily-summary-movement-count'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final int value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1F1A17), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                '$value',
                key: valueKey,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestPanel extends StatelessWidget {
  const _TestPanel({required this.controller, this.onSignOut});

  final PomogotchiHomeController controller;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    final status = controller.pomodoroState.status;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E8D0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F1A17), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PoC controls',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status == PomodoroScreenStatus.idle)
                _PanelButton(
                  label: 'Start focus',
                  onPressed: controller.canStartFocus
                      ? controller.startFocus
                      : null,
                ),
              if (status == PomodoroScreenStatus.focusActive ||
                  status == PomodoroScreenStatus.breakActive)
                _PanelButton(
                  label: 'Pause',
                  onPressed: controller.pauseSession,
                ),
              if (status == PomodoroScreenStatus.focusPaused ||
                  status == PomodoroScreenStatus.breakPaused)
                _PanelButton(
                  label: 'Resume',
                  onPressed: controller.resumeSession,
                ),
              if (status == PomodoroScreenStatus.focusActive ||
                  status == PomodoroScreenStatus.focusPaused ||
                  status == PomodoroScreenStatus.breakActive ||
                  status == PomodoroScreenStatus.breakPaused)
                _PanelButton(label: 'Stop', onPressed: controller.stopSession),
              if (status == PomodoroScreenStatus.focusCompleted)
                _PanelButton(
                  label: 'Start break',
                  onPressed: controller.startBreak,
                ),
              _PanelButton(
                label: 'Log water',
                onPressed: controller.canLogHydration
                    ? controller.logHydration
                    : null,
              ),
              _PanelButton(
                label: 'Log movement',
                onPressed: controller.canLogMovement
                    ? controller.logMovement
                    : null,
              ),
              _PanelButton(
                label: 'Reset',
                onPressed: controller.resetAll,
                isAccent: true,
              ),
              if (onSignOut != null)
                _PanelButton(label: 'Sign out', onPressed: onSignOut),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String? label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: isEnabled ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF4),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF1F1A17), width: 2.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 34, color: const Color(0xFF1F1A17)),
              if (label != null) ...[
                const SizedBox(height: 8),
                Text(
                  label!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeartButton extends StatelessWidget {
  const _HeartButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: enabled ? 1 : 0.45,
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF1F1A17), width: 3),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border_rounded,
                size: 36,
                color: Color(0xFFDA6C4B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.label,
    required this.onPressed,
    this.isAccent = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: isAccent
            ? const Color(0xFF2F5130)
            : const Color(0xFF544438),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label),
    );
  }
}

class _StageImage extends StatelessWidget {
  const _StageImage({required this.assetPath, required this.width});

  final String assetPath;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.pets_rounded,
          size: width * 0.55,
          color: const Color(0xFF544438),
        );
      },
    );
  }
}

class _EmptyPetStage extends StatelessWidget {
  const _EmptyPetStage();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.auto_awesome_rounded,
          size: 56,
          color: Color(0xFF544438),
        ),
        const SizedBox(height: 12),
        Text(
          'Waiting for a fresh Pomogotchi session',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAD8D0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB64024), width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFB64024)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF7A2C18),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
