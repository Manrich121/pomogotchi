# Split Pet Logic Into Synced Shared UI + macOS-Only Agent Runtime

## Summary
Refactor the app so both Apple targets keep using the same `PomogotchiHome` screen and the same high-level home controller contract, but pet behavior stops being local-only state.

The new architecture makes macOS the only runtime that creates bios and prompts Cactus. iOS becomes a synced companion client that reads pet state through PowerSync watched queries and writes user events into a synced event queue. macOS watches that queue, generates the pet response, and writes the handled state back into the database for iOS to render.

## Implementation Changes

### 1. Add synced pet tables and PowerSync streams
- Add a singleton `pet_sessions` table per user for the current pet snapshot:
  `id`, `owner_id`, `animal_id`, `bio_name`, `bio_summary`, `latest_speech`, `latest_event_id`, `last_error`, `created_at`, `updated_at`.
- Add an append-only `pet_events` table for cross-device pet actions:
  `id`, `owner_id`, `pet_session_id`, `event_type`, `source_device`, `status`, `reaction_speech`, `error_message`, `created_at`, `claimed_at`, `completed_at`.
- Extend the Flutter PowerSync schema and `docker/powersync.yaml` so both tables sync for the authenticated user.
- Use a local DB reset / reseed path instead of planning a migration or backfill.

### 2. Replace local pet state with a synced pet repository
- Introduce a `PetSyncRepository` that owns pet persistence and watched queries.
- Keep `PetSession` as the shared UI view model, but derive it from:
  `pet_sessions` snapshot + latest unresolved `pet_events` row + current synced pomodoro state.
- Use watched queries for:
  `watchCurrentPetSession()` for the screen snapshot,
  `watchPendingPetEvents()` for macOS processing,
  and a query that exposes pending/processing status for the shared UI.
- Do not sync a full transcript in this pass. Store only the latest rendered speech plus per-event response/error metadata.

### 3. Split pet orchestration by platform behind one controller contract
- Extract a small interface from the current `PetSessionController` that `PomogotchiHomeController` depends on:
  `session`, `bootstrap()`, `reset()`, `dispatch()`, `canDispatch()`, `Listenable`.
- Implement `MacosPetSessionController`:
  bootstrap seeds the pet if needed by selecting the animal and generating the bio with Cactus, then persisting it;
  dispatch enqueues a `pet_events` row;
  a background watcher claims pending events, generates the response, and writes the handled result back to `pet_events` and `pet_sessions`.
- Implement `IosPetSessionController`:
  no Cactus agents, no animal generation, no model initialization;
  bootstrap only subscribes to watched queries and waits for the synced pet to exist;
  dispatch only enqueues `pet_events` rows and relies on synced state updates from macOS.
- Select the controller in `pomogotchi_app.dart` by platform so the shared UI stays unchanged.

### 4. Make macOS authoritative for handled pet state
- Treat `pet_sessions` as macOS-authored state. iOS should not mutate the snapshot row directly.
- Let iOS user actions create `pet_events` with `status='pending'` and `source_device='ios'`.
- Let macOS claim pending events, process them, then mark them `completed` or `failed` and denormalize the latest speech into `pet_sessions`.
- Derive the “thinking” UI from pending/processing `pet_events` so iOS shows waiting state immediately without owning the pet snapshot.
- Derive prompt phase/context from the existing synced pomodoro tables instead of maintaining a separate local pet phase machine.

### 5. Keep reset and seed behavior explicit
- Update reset flows so `resetAll()` clears both pomodoro data and the synced pet tables, then macOS reseeds a fresh pet.
- If iOS opens before macOS has seeded the pet, show a passive waiting/empty state rather than trying to generate anything locally.
- Preserve sign-out behavior by clearing the local PowerSync DB as today.

## Public Interfaces And Types
- Add `PetSyncRepository` for pet snapshot queries, event enqueueing, and macOS event processing.
- Add platform-specific controller implementations behind the existing pet-controller contract.
- Extend the PowerSync schema with `pet_sessions` and `pet_events`.
- Add device-origin values for pet events, at minimum `macos` and `ios`.
- Add persisted pet-event statuses, at minimum `pending`, `processing`, `completed`, `failed`.

## Lean Validation
- Verify macOS first launch seeds one pet session and iOS can render it without initializing Cactus.
- Verify one iOS-origin pet event syncs to macOS, gets processed once, and updates speech on both devices.
- Verify one macOS-origin pet event still updates the shared UI correctly.
- Verify reset clears synced pet state and macOS reseeds a fresh pet.

## Assumptions
- macOS is the only pet-agent runtime; if it is offline, iOS queues events and waits rather than falling back locally.
- This pass syncs only the minimal pet snapshot needed by the current screen, not richer mood/bond stats and not the full transcript.
- Because this is a PoC, validation stays to a small smoke-test pass rather than extensive automated coverage.
- A local database reset is acceptable during development, so no compatibility migration/backfill work is required for the current prototype data.
