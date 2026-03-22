class DailyActivitySummary {
  const DailyActivitySummary({
    required this.id,
    required this.dayKey,
    required this.endedFocusCount,
    required this.endedBreakCount,
    required this.hydrationCount,
    required this.movementCount,
    required this.hydrationTimerAnchorAt,
    required this.hydrationReminderActive,
    required this.updatedAt,
    this.lastHydrationAt,
  });

  final String id;
  final String dayKey;
  final int endedFocusCount;
  final int endedBreakCount;
  final int hydrationCount;
  final int movementCount;
  final DateTime? lastHydrationAt;
  final DateTime hydrationTimerAnchorAt;
  final bool hydrationReminderActive;
  final DateTime updatedAt;

  DailyActivitySummary copyWith({
    String? id,
    String? dayKey,
    int? endedFocusCount,
    int? endedBreakCount,
    int? hydrationCount,
    int? movementCount,
    DateTime? lastHydrationAt,
    DateTime? hydrationTimerAnchorAt,
    bool? hydrationReminderActive,
    DateTime? updatedAt,
  }) {
    return DailyActivitySummary(
      id: id ?? this.id,
      dayKey: dayKey ?? this.dayKey,
      endedFocusCount: endedFocusCount ?? this.endedFocusCount,
      endedBreakCount: endedBreakCount ?? this.endedBreakCount,
      hydrationCount: hydrationCount ?? this.hydrationCount,
      movementCount: movementCount ?? this.movementCount,
      lastHydrationAt: lastHydrationAt ?? this.lastHydrationAt,
      hydrationTimerAnchorAt:
          hydrationTimerAnchorAt ?? this.hydrationTimerAnchorAt,
      hydrationReminderActive:
          hydrationReminderActive ?? this.hydrationReminderActive,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
