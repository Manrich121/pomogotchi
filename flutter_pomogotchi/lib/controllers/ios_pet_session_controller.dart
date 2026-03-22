import 'package:pomogotchi/controllers/pet_session_controller.dart';
import 'package:pomogotchi/features/pet/data/pet_sync_repository.dart';
import 'package:pomogotchi/models/pet_event.dart';

class IosPetSessionController extends SyncedPetSessionController {
  IosPetSessionController({required PetSyncRepository repository})
    : super(repository);

  bool _isBootstrapped = false;

  @override
  Future<void> bootstrap() async {
    if (_isBootstrapped) {
      return;
    }

    _isBootstrapped = true;
    setTransientErrorMessage(null);
    setInitializing(true);
    await attachSyncState();
  }

  @override
  Future<void> reset() async {
    setTransientErrorMessage(null);
    setInitializing(true);
    await repository.reset();
  }

  @override
  Future<void> dispatch(PetEvent event) async {
    if (!canDispatch(event)) {
      return;
    }

    setTransientErrorMessage(null);
    await repository.enqueueEvent(
      event: event,
      source: PetEventSource.ios,
      createdAt: DateTime.now().toUtc(),
    );
  }
}
