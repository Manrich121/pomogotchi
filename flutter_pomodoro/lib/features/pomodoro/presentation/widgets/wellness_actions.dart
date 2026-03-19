import 'dart:async';

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
          _WellnessActionButton(
            buttonKey: const Key('wellness-log-hydration'),
            semanticsLabel: 'Log hydration',
            label: 'Hydration',
            icon: Icons.local_drink_outlined,
            onPressed: onLogHydration,
            compact: true,
          ),
          const SizedBox(width: 12),
          _WellnessActionButton(
            buttonKey: const Key('wellness-log-movement'),
            semanticsLabel: 'Log movement',
            label: 'Movement',
            icon: Icons.directions_run_outlined,
            onPressed: onLogMovement,
            compact: true,
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
                  child: _WellnessActionButton(
                    buttonKey: const Key('wellness-log-hydration'),
                    semanticsLabel: 'Log hydration',
                    label: 'Hydration',
                    icon: Icons.local_drink_outlined,
                    onPressed: onLogHydration,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _WellnessActionButton(
                    buttonKey: const Key('wellness-log-movement'),
                    semanticsLabel: 'Log movement',
                    label: 'Movement',
                    icon: Icons.directions_run_outlined,
                    onPressed: onLogMovement,
                    outlined: true,
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

class _WellnessActionButton extends StatefulWidget {
  const _WellnessActionButton({
    required this.buttonKey,
    required this.semanticsLabel,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.compact = false,
    this.outlined = false,
    this.cooldown = const Duration(seconds: 5),
  });

  final Key buttonKey;
  final String semanticsLabel;
  final String label;
  final IconData icon;
  final Future<void> Function() onPressed;
  final bool compact;
  final bool outlined;
  final Duration cooldown;

  @override
  State<_WellnessActionButton> createState() => _WellnessActionButtonState();
}

class _WellnessActionButtonState extends State<_WellnessActionButton> {
  static const _successColor = Color(0xFF2E7D32);

  Timer? _cooldownTimer;
  Timer? _pulseTimer;
  bool _isSubmitting = false;
  bool _isCoolingDown = false;
  bool _isPulseActive = false;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pulseTimer?.cancel();
    super.dispose();
  }

  Future<void> _handlePressed() async {
    if (_isSubmitting || _isCoolingDown) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onPressed();
      if (!mounted) {
        return;
      }

      _cooldownTimer?.cancel();
      _pulseTimer?.cancel();
      setState(() {
        _isSubmitting = false;
        _isCoolingDown = true;
        _isPulseActive = true;
      });

      _pulseTimer = Timer(const Duration(milliseconds: 220), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _isPulseActive = false;
        });
      });

      _cooldownTimer = Timer(widget.cooldown, () {
        if (!mounted) {
          return;
        }
        setState(() {
          _isCoolingDown = false;
        });
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSuccess = _isCoolingDown;
    final isBusy = _isSubmitting;
    final foregroundColor = isSuccess
        ? Colors.white
        : widget.outlined
        ? colorScheme.primary
        : colorScheme.onPrimary;
    final backgroundColor = isSuccess
        ? _successColor
        : widget.outlined
        ? colorScheme.surface
        : colorScheme.primary;
    final borderSide = isSuccess
        ? BorderSide.none
        : widget.outlined
        ? BorderSide(color: colorScheme.outlineVariant)
        : BorderSide.none;
    final borderRadius = BorderRadius.circular(widget.compact ? 18 : 16);
    final iconChild = isBusy
        ? SizedBox.square(
            dimension: widget.compact ? 24 : 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          )
        : Icon(
            isSuccess ? Icons.check_rounded : widget.icon,
            key: ValueKey<bool>(isSuccess),
            size: widget.compact ? 32 : 20,
            color: foregroundColor,
          );

    return Semantics(
      button: true,
      enabled: !isBusy && !isSuccess,
      label: widget.semanticsLabel,
      value: isBusy
          ? 'Saving'
          : isSuccess
          ? 'Logged, temporarily disabled'
          : 'Ready',
      child: AnimatedScale(
        scale: _isPulseActive ? 1.06 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: isSuccess
                ? const [
                    BoxShadow(
                      color: Color(0x4D2E7D32),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: Material(
            color: backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius,
              side: borderSide,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: widget.buttonKey,
              onTap: isBusy || isSuccess ? null : _handlePressed,
              child: widget.compact
                  ? SizedBox(
                      width: 72,
                      height: 72,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: isSuccess
                              ? Column(
                                  key: const ValueKey<String>('success'),
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    iconChild,
                                    const SizedBox(height: 2),
                                    Text(
                                      'Saved',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: foregroundColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                )
                              : iconChild,
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: iconChild,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              isBusy
                                  ? 'Logging...'
                                  : isSuccess
                                  ? 'Logged'
                                  : widget.label,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: foregroundColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
