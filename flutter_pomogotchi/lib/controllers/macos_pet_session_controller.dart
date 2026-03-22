import 'dart:async';
import 'dart:math';

import 'package:pomogotchi/agents/narrative_agent.dart';
import 'package:pomogotchi/agents/pet_agent.dart';
import 'package:pomogotchi/controllers/pet_session_controller.dart';
import 'package:pomogotchi/features/pet/data/pet_sync_repository.dart';
import 'package:pomogotchi/models/animal_spec.dart';
import 'package:pomogotchi/models/pet_event.dart';

class MacosPetSessionController extends SyncedPetSessionController {
  MacosPetSessionController({
    required PetSyncRepository repository,
    required this.narrativeAgent,
    required this.petAgent,
    required this.animalLoader,
    Random? random,
  }) : random = random ?? Random(),
       super(repository);

  final NarrativeAgent narrativeAgent;
  final PetAgent petAgent;
  final Future<List<AnimalSpec>> Function() animalLoader;
  final Random random;

  bool _isBootstrapped = false;
  bool _isProcessingQueue = false;
  StreamSubscription<List<PetSyncEventRecord>>? _pendingEventsSubscription;

  @override
  Future<void> bootstrap() async {
    if (_isBootstrapped) {
      return;
    }

    _isBootstrapped = true;
    setTransientErrorMessage(null);
    setInitializing(true);
    await attachSyncState();
    if (currentSnapshot == null) {
      await _seedPetSession();
    } else {
      setInitializing(false);
    }
    _pendingEventsSubscription = repository.watchPendingPetEvents().listen((
      events,
    ) {
      if (events.isNotEmpty) {
        unawaited(_pumpPendingEvents());
      }
    });
    unawaited(_pumpPendingEvents());
  }

  @override
  Future<void> reset() async {
    setTransientErrorMessage(null);
    setInitializing(true);
    await repository.reset();
    await _seedPetSession();
  }

  @override
  Future<void> dispatch(PetEvent event) async {
    if (!canDispatch(event)) {
      return;
    }

    setTransientErrorMessage(null);
    await repository.enqueueEvent(
      event: event,
      source: PetEventSource.macos,
      createdAt: DateTime.now().toUtc(),
    );
    unawaited(_pumpPendingEvents());
  }

  Future<void> _seedPetSession() async {
    setGeneratingBio(true);
    try {
      final animals = await animalLoader();
      if (animals.isEmpty) {
        throw const FormatException(
          'No animal assets were found in assets/animals.',
        );
      }

      final selectedAnimal = animals[random.nextInt(animals.length)];
      final bio = await narrativeAgent.generateBio(selectedAnimal);
      await repository.seedPetSession(
        animalSpec: selectedAnimal,
        bio: bio,
        now: DateTime.now().toUtc(),
      );
      await refreshSyncState();
      setTransientErrorMessage(null);
    } catch (error) {
      setTransientErrorMessage(friendlyPetError(error));
    } finally {
      setGeneratingBio(false);
      setInitializing(false);
    }
  }

  Future<void> _pumpPendingEvents() async {
    if (_isProcessingQueue || isDisposed) {
      return;
    }

    _isProcessingQueue = true;
    try {
      while (!isDisposed) {
        final nextEvent = await repository.loadOldestPendingPetEvent();
        if (nextEvent == null) {
          return;
        }

        final now = DateTime.now().toUtc();
        await repository.markEventProcessing(
          eventId: nextEvent.id,
          claimedAt: now,
        );
        final processingEvent = await repository.loadPetEvent(nextEvent.id);
        if (processingEvent == null ||
            processingEvent.status != PetEventStatus.processing) {
          continue;
        }

        final snapshot = await repository.loadCurrentPetSession();
        if (snapshot == null) {
          await repository.failEvent(
            eventId: processingEvent.id,
            errorMessage: 'Cannot process pet events before the pet is seeded.',
            completedAt: DateTime.now().toUtc(),
          );
          continue;
        }

        try {
          final reaction = await petAgent.reactStream(
            event: processingEvent.event,
            sessionPhase: await repository.loadCurrentPhase(),
            bio: snapshot.bio,
            animalSpec: snapshot.animalSpec,
            transcript: const [],
            onChunk: (_) {},
          );
          await repository.completeEvent(
            eventId: processingEvent.id,
            speech: reaction.speech,
            completedAt: DateTime.now().toUtc(),
          );
        } catch (error) {
          await repository.failEvent(
            eventId: processingEvent.id,
            errorMessage: friendlyPetError(error),
            completedAt: DateTime.now().toUtc(),
          );
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  @override
  void dispose() {
    unawaited(_pendingEventsSubscription?.cancel());
    narrativeAgent.dispose();
    petAgent.dispose();
    super.dispose();
  }
}
