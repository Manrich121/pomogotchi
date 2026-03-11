# Pomogotchi Technical Implementation Plan

## Summary
Build Pomogotchi as a single Flutter codebase targeting macOS and iPhone, with macOS as the primary runtime and iPhone as a companion app. The main product mechanic is: the pet lives with you on Mac during work, then is transferred to the iPhone companion app for movement breaks, and explicitly returned to the Mac afterward.

The prototype should prove three things:
- The transfer ritual makes breaks feel tangible and playful.
- Cactus-powered on-device AI makes the pet feel alive without requiring cloud inference.
- PowerSync plus SQLite can support durable pet memory and retrieval-rich local context without turning memory into an untrustworthy black box.

## Key Implementation Changes
### 1. Product topology and device roles
- macOS is the main app and source of the daily work loop: timer control, pet home state, routine progress, and proactive break prompts.
- iPhone is a companion app used only when the pet leaves the Mac for a break or movement session, then returns explicitly to the Mac when the user ends that break.
- The pet must exist in exactly one active location at a time: `on_mac`, `transferring_to_phone`, `on_phone_break`, `returning_to_mac`, or `offline_recovering`.
- When a break transfer starts on macOS, the Mac UI switches to an away state and disables normal pet interactions until the pet is returned.
- Breaks remain `short_break` and `movement_break`; hydration is tracked separately as a check-in, not a break type.

### 2. Flutter app structure with Apple-specific surfaces
- Use Flutter for the shared app shell, shared domain logic, state management, AI orchestration, and common UI.
- Add thin platform-specific integrations for Apple-only surfaces that Flutter does not cover cleanly by default:
  - macOS menu bar presence and popover
  - iOS Live Activity
  - iOS widget
  - local notifications with actions
  - Sign in with Apple
- Make the macOS menu bar popover the primary interaction surface, with an optional full window only for onboarding, settings, and richer history.
- Keep the iPhone companion UI intentionally small: current break state, pet animation and state, one-tap movement and hydration completion, and a clear return-pet-to-Mac action.

### 3. Cactus on-device AI integration
- Use Cactus as the primary AI runtime for the prototype, with on-device inference on macOS and iPhone.
- Ship one default local model profile tuned for prototype responsiveness on Apple Silicon Macs and recent iPhones; do not expose model selection in the product.
- Bound AI usage to reactive pet moments only:
  - focus start
  - focus complete
  - missed break
  - hydration nudge
  - movement transfer invitation
  - in-break encouragement on iPhone
  - return-to-Mac acknowledgement
  - end-of-day reflection
- Keep the pet personality stable through a fixed system prompt and structured context assembly, even if the generated wording is highly variable.
- If Cactus inference fails, times out, or the model is unavailable, fall back to curated templates for the same trigger so the pet never appears broken.
- Keep durable memory separate from generated copy; generated text is not itself the main memory substrate.

### 4. Memory substrate and inference context
- Use PowerSync plus SQLite as the durable local-first memory substrate on both devices.
- Treat memory as three explicit classes:
  - `fact memory`: append-only canonical routine events and user actions
  - `summary memory`: daily derived relationship summaries and compact behavioral rollups
  - `interpreted memory`: AI-authored notable moments stored as interpretations, not raw facts
- Keep canonical facts app-authored only:
  - focus sessions
  - break sessions
  - hydration confirmations
  - movement confirmations
  - pet transfers between Mac and iPhone
  - explicit routine outcomes
- Let the app write daily summaries from canonical events and current pet state.
- Allow the AI to mark notable moments, but store them as typed interpreted memory that can influence retrieval and dialogue only; they must never be treated as factual input for pet-state updates.
- Retain raw routine events as first-class queryable memory for a rolling `30-90 day` horizon, then rely on summaries for older continuity.
- Build inference context from:
  - bounded recent routine events
  - current pet state
  - latest daily summaries
  - selected notable interpreted memories
  - current device role and time of day
- Use semantic retrieval over daily summaries plus selected notable memories, rather than over the full raw event table.
- Generate embeddings through a hybrid path:
  - local generation when feasible on device
  - optional server-generated embeddings only from sanitized summaries, never from the full raw event stream
- Keep the memory trust model explicit in retrieval and prompt assembly:
  - facts can support pet-state derivation
  - summaries can support continuity and higher-level context
  - interpreted memories can support recall and personality, but not factual state transitions

## Public Interfaces And Types
- `PetLocationState`: current location, transfer timestamp, transfer source, expected return target
- `PetState`: mood, energy, hydration, restlessness, bond, activeLocation, lastReactionAt
- `RoutineEvent`: id, type, timestamp, sourceDevice, relatedSessionId, metadata
- `FocusSession`: id, plannedDuration, startedAt, endedAt, outcome, interruptionReason
- `BreakSession`: id, breakType, startedAt, endedAt, startedOnDevice, completedOnDevice, petTransferRequired
- `DailyProgress`: date, focusCount, breakCount, hydrationCount, movementCount, balanceScore
- `DailyMemorySummary`: date, structured behavioral recap, bond delta, notable patterns, embeddingRef
- `InterpretedMemory`: id, sourceTrigger, createdAt, interpretationType, textSummary, confidence, embeddingRef
- `PetPromptContext`: current pet state, recent routine events, time-of-day, current device role, summary memories, interpreted memories
- `AIReaction`: trigger, generatedText, latencyMs, fallbackUsed, validationResult
- `UserProfile`: Apple identity, preferred routine defaults, notification preferences, prototype flags

## Data, Sync, And Identity
- Keep the app local-first, with all timer, pet, and routine logic working offline on each device.
- Use Sign in with Apple as the only identity mechanism.
- Use PowerSync for structured state continuity between the user's Mac and iPhone; SQLite is the local durable store on each device.
- Sync only the minimum required records: profile, pet state snapshot, routine events, break transfer state, daily summaries, interpreted memories, and preferences.
- Use append-only routine events plus derived pet state so offline actions can reconcile cleanly across Mac and iPhone.
- Apply `last-write-wins` only to derived pet state, summary rows, interpreted-memory updates if mutable, and settings and preferences.
- Make macOS authoritative for active work sessions and iPhone authoritative only while the pet is in companion-break mode.

## Test Plan
- User can sign in on both devices and see the same pet bond and state.
- User can complete focus sessions entirely on macOS without opening iPhone.
- A movement break prompt on macOS can transfer the pet to iPhone and place the Mac in an away state.
- The iPhone companion app can complete a break and explicitly return the pet to macOS without duplicating events.
- Hydration and movement confirmations update pet state correctly on both devices after sync.
- Daily summaries are written deterministically from canonical events and remain stable across sync and rebuilds.
- AI-selected notable moments are stored as interpreted memory and never alter pet state as if they were raw facts.
- Semantic retrieval can pull relevant summaries and interpreted memories without scanning all raw event history.
- Cactus reactions stay in character across several days of mixed use on both devices.
- Template fallback appears cleanly when local inference fails.
- Offline Mac and offline iPhone actions reconcile into one coherent event stream when connectivity returns.
- Live Activity and widget reflect companion-mode state accurately while the pet is on iPhone.

## Assumptions And Defaults
- React Native is the only app framework; Apple-specific surfaces use native integrations where required.
- Cactus is the main AI inference layer and runs primarily on-device.
- PowerSync plus SQLite is the durable memory substrate, not just transport or cache.
- The first usable prototype targets macOS and iPhone only.
- The menu bar popover is the required macOS shell; a desktop widget remains out of scope for the first pass.
- The iPhone app is not a full peer client; it is a companion experience centered on break transfer and return.
- Coffee is out of scope as a distinct break type.
- AI-authored memory is allowed only as explicitly typed interpreted memory.
- Success is measured primarily by whether the Mac-to-iPhone companion transfer loop and AI pet reactions make breaks feel emotionally compelling.
