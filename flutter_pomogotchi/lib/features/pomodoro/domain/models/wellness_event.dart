enum WellnessEventType { hydration, movement }

class WellnessEvent {
  const WellnessEvent({
    required this.id,
    required this.dayKey,
    required this.type,
    required this.occurredAt,
  });

  final String id;
  final String dayKey;
  final WellnessEventType type;
  final DateTime occurredAt;
}
