import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomogotchi/agents/narrative_agent.dart';
import 'package:pomogotchi/agents/pet_agent.dart';
import 'package:pomogotchi/controllers/pet_session_controller.dart';
import 'package:pomogotchi/models/animal_spec.dart';
import 'package:pomogotchi/models/pet_bio.dart';
import 'package:pomogotchi/models/pet_event.dart';
import 'package:pomogotchi/models/pet_reaction.dart';
import 'package:pomogotchi/models/pet_transcript_entry.dart';
import 'package:pomogotchi/models/session_phase.dart';
import 'package:pomogotchi/pomogotchi_app.dart';

void main() {
  testWidgets('bootstraps a pet session and applies valid phase transitions', (
    WidgetTester tester,
  ) async {
    final petAgent = _FakePetAgent();
    final controller = PetSessionController(
      narrativeAgent: _FakeNarrativeAgent(),
      petAgent: petAgent,
      animalLoader: () async => [
        AnimalSpec.fromAnimalAsset('assets/animals/dog.png'),
      ],
      random: Random(1),
    );

    await tester.pumpWidget(PomogotchiApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Bernie'), findsOneWidget);
    expect(find.textContaining('ready to keep you company'), findsOneWidget);

    await tester.tap(find.text('Start focus'));
    await tester.pumpAndSettle();

    expect(controller.session.phase, SessionPhase.focusInProgress);
    expect(
      find.text('Focus face on. I am perched right here with you.'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Complete focus'),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Complete focus'));
    await tester.pumpAndSettle();

    expect(controller.session.phase, SessionPhase.idle);
    expect(petAgent.events, [
      PetEvent.startFocusSession,
      PetEvent.completeFocusSession,
    ]);
    expect(
      find.text('That was strong work. Take the win, then breathe out.'),
      findsOneWidget,
    );
  });
}

class _FakeNarrativeAgent implements NarrativeAgent {
  @override
  Future<PetBio> generateBio(AnimalSpec animalSpec) async {
    return const PetBio(
      name: 'Bernie',
      summary: 'A scrappy little hype machine with a soft spot for effort.',
    );
  }

  @override
  void dispose() {}
}

class _FakePetAgent implements PetAgent {
  final List<PetEvent> events = [];

  @override
  Future<PetReaction> reactStream({
    required PetEvent event,
    required SessionPhase sessionPhase,
    required PetBio bio,
    required AnimalSpec animalSpec,
    required List<PetTranscriptEntry> transcript,
    required void Function(String chunk) onChunk,
  }) async {
    events.add(event);
    final speech = switch (event) {
      PetEvent.startFocusSession =>
        'Focus face on. I am perched right here with you.',
      PetEvent.completeFocusSession =>
        'That was strong work. Take the win, then breathe out.',
      _ => '${bio.name} noticed ${event.wireValue}.',
    };

    onChunk(speech.substring(0, speech.length ~/ 2));
    onChunk(speech.substring(speech.length ~/ 2));

    return PetReaction(speech: speech);
  }

  @override
  void dispose() {}
}
