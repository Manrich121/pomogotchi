import 'package:flutter/material.dart';
import 'package:flutter_pomodoro/features/pomodoro/domain/models/daily_activity_summary.dart';

class DailySummaryPanel extends StatelessWidget {
  const DailySummaryPanel({super.key, required this.summary});

  final DailyActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
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
      width: 150,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
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
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
