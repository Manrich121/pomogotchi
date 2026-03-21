# Pomogotchi PoC Plan

## Summary
- Build the first PoC around the model interaction loop, not a real pomodoro timer.
- Use two model roles: a narrative agent that generates a structured pet bio once per session, and a pet agent that reacts to user-triggered events.
- Treat reset as a full new session: regenerate the pet, clear transcript state, and restart the flow.
- Use the layout and visual hierarchy from [wireframes/main-screen-wireframe.png](/Users/manrichvangreunen/Documents/my-projects/pomogotchi/flutter_pomogotchi/wireframes/main-screen-wireframe.png) as the basis for the main screen, with an added test-controls area so all PoC events remain accessible.

## Product Direction
- Keep the published `cactus` dependency and current model split unless implementation proves they need to change.
- Prefix the system prompt for both models with `/no_think` so responses contain only the requested output.
- Remove the prior tool-calling interaction design. In this PoC, the pet agent does not generate buttons, choices, or tool calls.
- Simplify the bio to strict structured output parsed into `PetBio { name, summary }`.
- Require the narrative prompt to return:
  - a one-word pet name
  - a brief summary describing the specific animal's personality or vibe
  - JSON only
- Hide the generated bio from the player. It is used only as context for the pet agent system prompt.
- Have the pet agent react to app-originated events with 1-2 short sentences that stay in character and do not ask the app to render options.

## Interaction Loop
- Support this fixed event set:
  - `start_focus_session`
  - `complete_focus_session`
  - `stop_focus_session_early`
  - `start_break`
  - `complete_break`
  - `stop_break_early`
  - `pet_pet`
  - `drink_water`
  - `move_or_stretch`
- Use a lightweight in-memory phase model:
  - `idle`
  - `focus_in_progress`
  - `break_in_progress`
- Apply transitions as follows:
  - `start_focus_session`: `idle -> focus_in_progress`
  - `complete_focus_session`: `focus_in_progress -> idle`
  - `stop_focus_session_early`: `focus_in_progress -> idle`
  - `start_break`: `idle -> break_in_progress`
  - `complete_break`: `break_in_progress -> idle`
  - `stop_break_early`: `break_in_progress -> idle`
  - wellness events do not change phase
- Keep session state in memory only for v1: selected animal, generated bio, transcript/history, latest reaction, current phase, and loading/error flags.
- On app boot:
  - discover available animals from `assets/animals`
  - choose one animal for the session
  - generate the structured bio
  - compose the pet agent prompt
  - show the ready state
- On reset:
  - clear the current session state
  - choose or regenerate a new pet session
  - generate a fresh bio
  - restart the interaction flow

## Response Handling
- Use `generateCompletion()` for the narrative agent because the bio must be parsed from one final response string.
- Use `generateCompletionStream()` for the pet agent, following the `cactus-flutter` example patterns in:
  - [streaming_completion.dart](https://github.com/cactus-compute/cactus-flutter/blob/main/example/lib/pages/streaming_completion.dart)
  - [chat.dart](https://github.com/cactus-compute/cactus-flutter/blob/main/example/lib/pages/chat.dart)
- Handle pet responses like this:
  - start a pending assistant reaction state before invoking the model
  - append streamed chunks into transient UI text as they arrive
  - keep separate loading and streaming flags so the UI can distinguish "thinking" from visible streamed output
  - await `streamedResult.result` after streaming completes
  - treat `result.response` as the canonical final assistant message for transcript/history storage
- Do not parse structured data from stream chunks.
- Do not rely on `toolCalls` for the pet loop in this PoC.
- If bio parsing fails, retry once, then surface an error state.
- Surface recoverable error states for both agents and leave the previous stable UI visible when a reaction fails.

## Code Structure
- Follow a Mastra-style organization pattern in Flutter by keeping each agent in its own file under `lib/agents`.
- Add:
  - `lib/agents/narrative_agent.dart`: bio prompt, model configuration, JSON parsing, retry handling
  - `lib/agents/pet_agent.dart`: pet system prompt builder, event payload builder, streamed reaction generation
- Keep domain models separate from agent code:
  - `PetBio`
  - `PetEvent`
  - `PetSession`
  - `SessionPhase`
  - `PetReaction`
- Add a single orchestration layer that owns:
  - animal selection
  - agent calls
  - phase transitions
  - transcript updates
  - streaming state
  - reset flow
- Keep UI code focused on rendering current state and dispatching typed events.
- Dispose long-lived `CactusLM` instances when the owning controller or screen is torn down.

## UI Plan
- Base the main screen layout on the referenced wireframe:
  - top action row
  - pet name
  - centered speech bubble
  - pet art and platform
  - prominent affection control
- Map the primary wireframe controls to these actions:
  - top-left: `start focus`
  - top-center: `drink water`
  - top-right: `move or stretch`
  - lower-left heart: `pet pet`
- Add a clearly labeled test panel for the remaining PoC actions:
  - `complete focus`
  - `stop focus early`
  - `start break`
  - `complete break`
  - `stop break early`
  - `reset`
- Disable phase-invalid controls, but keep wellness actions available at all times.
- Show clear states for:
  - generating bio
  - pet thinking
  - streamed reply in progress
  - recoverable errors

## Interfaces
- `PetBio`: `name`, `summary`
- `PetEvent`: closed enum for the supported interaction events
- `SessionPhase`: `idle`, `focusInProgress`, `breakInProgress`
- `PetReaction`: `speech`
- `PetSession`: selected animal metadata, `PetBio`, `SessionPhase`, transcript/history, latest reaction, loading/error status
- `NarrativeAgent.generateBio(animalSpec) -> PetBio`
- `PetAgent.reactStream({event, sessionPhase, bio, transcript}) -> streamed speech + final PetReaction`

## Assumptions
- This is a PoC, so automated tests are intentionally deferred until the interaction model and prompt contracts stabilize.
- "Mastra's approach" means mirroring an agent-per-file structure in `lib/agents`, not adding a TypeScript Mastra runtime to this Flutter app.
- The bio remains hidden from the user in this version and is used only to shape the pet agent's behavior.
- The pet agent returns short natural-language reactions, not structured UI commands.
- Countdown timers, persistence across launches, and production onboarding are out of scope for this phase.
