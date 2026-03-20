# Pomogotchi v1 Plan

## Summary
- Build `pomogotchi` as a standalone Flutter app that depends on the published `cactus` package via `flutter pub add cactus`, not a local path dependency to this SDK repo.
- On every cold launch, discover the available animals from the asset filenames under `assets/animals`, pick one at random, and start a new ephemeral pet session for that launch.
- Auto-download `gemma3-270m` and `qwen3-0.6` if needed, use `gemma3-270m` once to generate the selected pet's bio, then keep `qwen3-0.6` loaded for the interactive pet loop.
- The generated bio must include the pet's name, where it is from, and its favourite food. That bio is hidden from the user and used as the pet model's system prompt context.

## Key Changes
- Update `pomogotchi/pubspec.yaml` to add the published `cactus` dependency and register the animal assets. Do not reference the repo-root package by path.
- Replace the template app with a small app state machine: `bootstrapping -> generatingBio -> petThinking -> awaitingChoice | idling -> petThinking`.
- Discover animals from Flutter's asset manifest, filter `assets/animals/*.png`, sort for deterministic tests, and derive the species id/display label from the filename stem, for example `bear.png` -> species `bear` / label `Bear`.
- Add an in-memory `PetSession` model with `animalSpecies`, `imageAsset`, `bio`, `transcript`, `currentTurn`, and `status`. Session state resets on cold launch.
- Generate the bio with a fixed narrative prompt that tells the model to invent:
  - the pet's individual name
  - where it is from
  - its favourite food
  - a short summary sentence tying those details to the selected species
- Persist the bio inside the session object and use it to compose the pet model's system prompt. The pet prompt should also require 1-2 short sentences, no typed input, and only tool-based UI actions.
- Use a long-lived `CactusLM` instance for the pet model and an app-owned conversation engine that:
  - appends synthetic `user` messages for button taps and idle wakeups
  - calls `generateCompletion`
  - inspects returned `toolCalls`
  - updates UI state
- Define exactly two pet tools:
  - `show_choices(speech, option1Label, option1Value, option2Label, option2Value)`
  - `end_turn(speech)`
- Render a single-screen scene with the selected animal avatar, a speech bubble, and up to two response buttons. When the pet returns `end_turn`, show only the speech bubble and arm the short foreground idle timer.

## Interfaces
- `PomogotchiConfig`: published `cactus` dependency, `narrativeModelSlug = gemma3-270m`, `petModelSlug = qwen3-0.6`, `idleDelay = 60s`.
- `PetBio`: `name`, `origin`, `favoriteFood`, `summary`.
- `AnimalSpec`: `speciesId`, `displayLabel`, `imageAsset`.
- `PetTurn`: `speech`, `choices` nullable, `idleUntil` nullable.
- `PetChoice`: `label`, `value`.

## Test Plan
- Unit test animal discovery from asset-manifest filenames, including parsing `bear.png`.
- Unit test bootstrap behavior for missing models vs already-downloaded models.
- Unit test bio generation parsing/storage so `name`, `origin`, `favoriteFood`, and `summary` are all present.
- Unit test pet tool handling for valid `show_choices`, valid `end_turn`, missing arguments, and unknown tool names.
- Unit test conversation transitions: first prompt, choice tap, passive turn to idle, and idle wakeup.
- Widget test avatar rendering, speech bubble updates, two-button rendering for `show_choices`, and no buttons for `end_turn`.

## Assumptions
- "App start" means a cold launch; the selected animal and generated bio are not restored across launches.
- The bio is hidden from the player in v1 and only used to shape pet behavior.
- iOS and macOS remain the planned v1 targets.
- The published `cactus` package exposes the same core LM/tool-calling APIs used by the current SDK examples.
