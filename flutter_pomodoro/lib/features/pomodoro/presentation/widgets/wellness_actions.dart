import 'package:flutter/material.dart';

class WellnessActions extends StatelessWidget {
  const WellnessActions({
    super.key,
    required this.onLogHydration,
    required this.onLogMovement,
    this.compact = false,
  });

  final Future<void> Function() onLogHydration;
  final Future<void> Function() onLogMovement;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CompactWellnessButton(
            buttonKey: const Key('wellness-log-hydration'),
            semanticsLabel: 'Log hydration',
            icon: Icons.local_drink_outlined,
            onPressed: onLogHydration,
          ),
          const SizedBox(width: 12),
          _CompactWellnessButton(
            buttonKey: const Key('wellness-log-movement'),
            semanticsLabel: 'Log movement',
            icon: Icons.directions_run_outlined,
            onPressed: onLogMovement,
          ),
        ],
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Wellness', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('wellness-log-hydration'),
                    onPressed: () => onLogHydration(),
                    icon: const Icon(Icons.local_drink_outlined),
                    label: const Text('Hydration'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('wellness-log-movement'),
                    onPressed: () => onLogMovement(),
                    icon: const Icon(Icons.directions_run_outlined),
                    label: const Text('Movement'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactWellnessButton extends StatelessWidget {
  const _CompactWellnessButton({
    required this.buttonKey,
    required this.semanticsLabel,
    required this.icon,
    required this.onPressed,
  });

  final Key buttonKey;
  final String semanticsLabel;
  final IconData icon;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: SizedBox(
        width: 72,
        height: 72,
        child: FilledButton(
          key: buttonKey,
          onPressed: () => onPressed(),
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: ExcludeSemantics(
            child: Icon(
              icon,
              size: 32,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
