import 'dart:async';
import 'dart:math';

import 'package:cactus/cactus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pomogotchi/agents/narrative_agent.dart';
import 'package:pomogotchi/agents/pet_agent.dart';
import 'package:pomogotchi/controllers/pet_session_controller.dart';
import 'package:pomogotchi/models/pet_event.dart';
import 'package:pomogotchi/models/pet_session.dart';
import 'package:pomogotchi/models/session_phase.dart';
import 'package:pomogotchi/services/animal_catalog.dart';

class PomogotchiHome extends StatefulWidget {
  const PomogotchiHome({super.key, this.controller});

  final PetSessionController? controller;

  @override
  State<PomogotchiHome> createState() => _PomogotchiHomeState();
}

class _PomogotchiHomeState extends State<PomogotchiHome> {
  late final PetSessionController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? _buildController();
    unawaited(_controller.bootstrap());
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  PetSessionController _buildController() {
    const cactusToken = String.fromEnvironment('CACTUS_TOKEN');
    const cactusModel = String.fromEnvironment(
      'CACTUS_MODEL',
      defaultValue: 'qwen3-0.6',
    );
    final token = cactusToken.isEmpty ? null : cactusToken;
    final completionMode = token == null
        ? CompletionMode.local
        : CompletionMode.hybrid;

    return PetSessionController(
      narrativeAgent: CactusNarrativeAgent(
        model: cactusModel,
        completionMode: completionMode,
        cactusToken: token,
      ),
      petAgent: CactusPetAgent(
        model: cactusModel,
        completionMode: completionMode,
        cactusToken: token,
      ),
      animalLoader: () => discoverAnimalSpecs(rootBundle),
      random: Random(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final session = _controller.session;

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
                                _TopActionRow(controller: _controller),
                                const SizedBox(height: 18),
                                _SessionHeader(session: session),
                                if (session.errorMessage != null) ...[
                                  const SizedBox(height: 12),
                                  _ErrorBanner(message: session.errorMessage!),
                                ],
                                const SizedBox(height: 18),
                                _SpeechBubble(
                                  speech: _displayedSpeech(session),
                                  isPending:
                                      session.isThinking || session.isStreaming,
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: max(280, constraints.maxHeight - 430),
                                  child: _PetStage(
                                    session: session,
                                    controller: _controller,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _TestPanel(controller: _controller),
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

  String _displayedSpeech(PetSession session) {
    if (session.pendingSpeech.trim().isNotEmpty) {
      return session.pendingSpeech.trim();
    }

    if (session.latestReaction != null) {
      return session.latestReaction!.speech;
    }

    if (session.isGeneratingBio) {
      return 'Choosing an animal and generating a hidden bio...';
    }

    if (session.errorMessage != null) {
      return 'Bootstrap failed: ${session.errorMessage!}';
    }

    return 'Reset to spin up a fresh Pomogotchi session.';
  }
}

class _TopActionRow extends StatelessWidget {
  const _TopActionRow({required this.controller});

  final PetSessionController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PrimaryActionButton(
            label: PetEvent.startFocusSession.label,
            icon: Icons.play_arrow_rounded,
            onPressed: controller.canDispatch(PetEvent.startFocusSession)
                ? () => controller.dispatch(PetEvent.startFocusSession)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PrimaryActionButton(
            label: PetEvent.drinkWater.label,
            icon: Icons.local_drink_outlined,
            onPressed: controller.canDispatch(PetEvent.drinkWater)
                ? () => controller.dispatch(PetEvent.drinkWater)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PrimaryActionButton(
            label: PetEvent.moveOrStretch.label,
            icon: Icons.accessibility_new_rounded,
            onPressed: controller.canDispatch(PetEvent.moveOrStretch)
                ? () => controller.dispatch(PetEvent.moveOrStretch)
                : null,
          ),
        ),
      ],
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session});

  final PetSession session;

  @override
  Widget build(BuildContext context) {
    final name = session.bio?.name ?? 'Summoning pet';

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
  const _SpeechBubble({required this.speech, required this.isPending});

  final String speech;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF1F1A17), width: 3),
          ),
          child: Text(
            speech,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
        if (isPending)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Reply in progress',
              style: TextStyle(
                color: Color(0xFF6A5B52),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _PetStage extends StatelessWidget {
  const _PetStage({required this.session, required this.controller});

  final PetSession session;
  final PetSessionController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.bottomCenter,
          child: session.animal == null
              ? const _EmptyPetStage()
              : Transform.translate(
                  offset: const Offset(0, -10),
                  child: _StageImage(
                    assetPath: session.animal!.artAssetPath,
                    width: 185,
                  ),
                ),
        ),
        Positioned(
          left: 0,
          bottom: 12,
          child: _HeartButton(
            enabled: controller.canDispatch(PetEvent.petPet),
            onPressed: () => controller.dispatch(PetEvent.petPet),
          ),
        ),
      ],
    );
  }
}

class _TestPanel extends StatelessWidget {
  const _TestPanel({required this.controller});

  final PetSessionController controller;

  @override
  Widget build(BuildContext context) {
    final panelEvents = [
      PetEvent.completeFocusSession,
      PetEvent.stopFocusSessionEarly,
      PetEvent.startBreak,
      PetEvent.completeBreak,
      PetEvent.stopBreakEarly,
    ];

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
              for (final event in panelEvents)
                _PanelButton(
                  label: event.label,
                  onPressed: controller.canDispatch(event)
                      ? () => controller.dispatch(event)
                      : null,
                ),
              _PanelButton(
                label: 'Reset',
                onPressed: controller.reset,
                isAccent: true,
              ),
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

  final String label;
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
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
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
              SizedBox(height: 2),
              Text(
                'Pet pet',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
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
