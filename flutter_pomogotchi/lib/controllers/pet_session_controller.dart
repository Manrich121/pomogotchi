import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pomogotchi/agents/narrative_agent.dart';
import 'package:pomogotchi/agents/pet_agent.dart';
import 'package:pomogotchi/models/animal_spec.dart';
import 'package:pomogotchi/models/pet_event.dart';
import 'package:pomogotchi/models/pet_reaction.dart';
import 'package:pomogotchi/models/pet_session.dart';
import 'package:pomogotchi/models/pet_transcript_entry.dart';
import 'package:pomogotchi/models/session_phase.dart';

class PetSessionController extends ChangeNotifier {
  PetSessionController({
    required this.narrativeAgent,
    required this.petAgent,
    required this.animalLoader,
    Random? random,
  }) : random = random ?? Random();

  final NarrativeAgent narrativeAgent;
  final PetAgent petAgent;
  final Future<List<AnimalSpec>> Function() animalLoader;
  final Random random;

  PetSession _session = PetSession.initial();
  int _operationId = 0;
  bool _isDisposed = false;

  PetSession get session => _session;

  Future<void> bootstrap() async {
    await _startNewSession();
  }

  Future<void> reset() async {
    await _startNewSession();
  }

  bool canDispatch(PetEvent event) {
    if (_session.isInitializing ||
        _session.isThinking ||
        _session.isStreaming) {
      return false;
    }

    if (!_session.hasActiveSession) {
      return false;
    }

    return _nextPhaseFor(event, _session.phase) != null;
  }

  Future<void> dispatch(PetEvent event) async {
    if (!canDispatch(event)) {
      return;
    }

    final currentSession = _session;
    final animal = currentSession.animal;
    final bio = currentSession.bio;
    final nextPhase = _nextPhaseFor(event, currentSession.phase);

    if (animal == null || bio == null || nextPhase == null) {
      return;
    }

    final currentOperation = ++_operationId;
    final pendingSpeech = StringBuffer();
    final eventPayload = buildPetEventPayload(
      event: event,
      sessionPhase: currentSession.phase,
    );

    _setSession(
      currentSession.copyWith(
        isThinking: true,
        isStreaming: false,
        pendingSpeech: '',
        errorMessage: null,
      ),
    );

    try {
      final reaction = await petAgent.reactStream(
        event: event,
        sessionPhase: currentSession.phase,
        bio: bio,
        animalSpec: animal,
        transcript: currentSession.transcript,
        onChunk: (chunk) {
          if (!_isCurrent(currentOperation)) {
            return;
          }

          pendingSpeech.write(chunk);
          _setSession(
            _session.copyWith(
              isThinking: false,
              isStreaming: true,
              pendingSpeech: pendingSpeech.toString(),
              errorMessage: null,
            ),
          );
        },
      );

      if (!_isCurrent(currentOperation)) {
        return;
      }

      final updatedTranscript =
          List<PetTranscriptEntry>.of(currentSession.transcript)
            ..add(PetTranscriptEntry.user(eventPayload))
            ..add(PetTranscriptEntry.assistant(reaction.speech));

      _setSession(
        currentSession.copyWith(
          phase: nextPhase,
          transcript: updatedTranscript,
          latestReaction: reaction,
          pendingSpeech: '',
          isThinking: false,
          isStreaming: false,
          errorMessage: null,
        ),
      );
    } catch (error) {
      if (!_isCurrent(currentOperation)) {
        return;
      }

      debugPrint('Pomogotchi reaction failed for ${event.wireValue}: $error');
      _setSession(
        currentSession.copyWith(
          isThinking: false,
          isStreaming: false,
          pendingSpeech: '',
          errorMessage: _friendlyError(error),
        ),
      );
    }
  }

  SessionPhase? _nextPhaseFor(PetEvent event, SessionPhase currentPhase) {
    return switch (event) {
      PetEvent.startFocusSession =>
        currentPhase == SessionPhase.idle ? SessionPhase.focusInProgress : null,
      PetEvent.completeFocusSession || PetEvent.stopFocusSessionEarly =>
        currentPhase == SessionPhase.focusInProgress ? SessionPhase.idle : null,
      PetEvent.startBreak =>
        currentPhase == SessionPhase.idle ? SessionPhase.breakInProgress : null,
      PetEvent.completeBreak || PetEvent.stopBreakEarly =>
        currentPhase == SessionPhase.breakInProgress ? SessionPhase.idle : null,
      PetEvent.petPet ||
      PetEvent.drinkWater ||
      PetEvent.moveOrStretch => currentPhase,
    };
  }

  Future<void> _startNewSession() async {
    final currentOperation = ++_operationId;

    _setSession(
      PetSession.initial().copyWith(
        isInitializing: true,
        isGeneratingBio: true,
        errorMessage: null,
      ),
    );

    try {
      final animals = await animalLoader();
      if (animals.isEmpty) {
        throw const FormatException(
          'No animal assets were found in assets/animals.',
        );
      }

      final selectedAnimal = animals[random.nextInt(animals.length)];
      final bio = await narrativeAgent.generateBio(selectedAnimal);

      if (!_isCurrent(currentOperation)) {
        return;
      }

      _setSession(
        PetSession.initial().copyWith(
          animal: selectedAnimal,
          bio: bio,
          latestReaction: PetReaction(
            speech:
                '${bio.name} the ${selectedAnimal.displayName.toLowerCase()} hops onto the platform, ready to keep you company.',
          ),
          isInitializing: false,
          isGeneratingBio: false,
          errorMessage: null,
        ),
      );
    } catch (error) {
      if (!_isCurrent(currentOperation)) {
        return;
      }

      debugPrint('Pomogotchi bootstrap failed: $error');
      _setSession(
        PetSession.initial().copyWith(
          isInitializing: false,
          isGeneratingBio: false,
          errorMessage: _friendlyError(error),
        ),
      );
    }
  }

  bool _isCurrent(int operationId) {
    return !_isDisposed && operationId == _operationId;
  }

  void _setSession(PetSession nextSession) {
    if (_isDisposed) {
      return;
    }

    _session = nextSession;
    notifyListeners();
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  @override
  void dispose() {
    _isDisposed = true;
    narrativeAgent.dispose();
    petAgent.dispose();
    super.dispose();
  }
}
