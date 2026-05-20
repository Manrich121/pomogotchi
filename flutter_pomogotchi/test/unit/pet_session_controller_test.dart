import 'package:flutter_test/flutter_test.dart';
import 'package:pomogotchi/controllers/pet_session_controller.dart';
import 'package:pomogotchi/models/animal_spec.dart';
import 'package:pomogotchi/models/pet_bio.dart';
import 'package:pomogotchi/models/pet_event.dart';
import 'package:pomogotchi/models/pet_reaction.dart';
import 'package:pomogotchi/models/pet_session.dart';
import 'package:pomogotchi/models/session_phase.dart';

void main() {
  test('busy pet still accepts focus lifecycle events', () {
    final controller = _FakePetSessionController(
      PetSession.initial().copyWith(
        animal: AnimalSpec.fromAnimalAsset('assets/animals/dog.png'),
        bio: const PetBio(name: 'Bernie', summary: 'Focused and scrappy.'),
        phase: SessionPhase.focusInProgress,
        latestReaction: const PetReaction(speech: 'Focused and scrappy.'),
        isThinking: true,
      ),
    );

    expect(controller.canDispatch(PetEvent.resumeFocusSession), isTrue);
    expect(controller.canDispatch(PetEvent.stopFocusSessionEarly), isTrue);
    expect(controller.canDispatch(PetEvent.petPet), isFalse);
  });

  test(
    'phase gate still accepts lifecycle events after synced phase already moved',
    () {
      expect(
        nextPhaseFor(PetEvent.startFocusSession, SessionPhase.focusInProgress),
        SessionPhase.focusInProgress,
      );
      expect(
        nextPhaseFor(PetEvent.stopFocusSessionEarly, SessionPhase.idle),
        SessionPhase.idle,
      );
      expect(
        nextPhaseFor(PetEvent.completeFocusSession, SessionPhase.idle),
        SessionPhase.idle,
      );
      expect(
        nextPhaseFor(PetEvent.startBreak, SessionPhase.breakInProgress),
        SessionPhase.breakInProgress,
      );
      expect(
        nextPhaseFor(PetEvent.stopBreakEarly, SessionPhase.idle),
        SessionPhase.idle,
      );
    },
  );
}

class _FakePetSessionController extends PetSessionController {
  _FakePetSessionController(this._session);

  final PetSession _session;

  @override
  PetSession get session => _session;

  @override
  Future<void> bootstrap() async {}

  @override
  Future<void> dispatch(PetEvent event) async {}

  @override
  Future<void> reset() async {}
}
