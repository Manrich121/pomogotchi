# Pomogotchi MVP Product Spec

## Summary
Pomogotchi MVP is a focus-and-wellbeing companion for solo desk workers. The core promise is to help users sustain a healthier work rhythm by making breaks, hydration, and movement feel emotionally rewarding through a single digital pet.

The MVP should validate three things:
- Users return for the pet, not just the timer.
- A structured routine feels helpful rather than nagging.
- Simple daily balance matters more than maximizing raw focus time.

## Core Product Definition
- The product centers on one main pet with a distinct, playful personality.
  Why: attachment is stronger with one companion, and MVP scope stays focused.
- The primary user loop is: start a focus session, take a break, respond to hydration prompts, complete a short movement break, and see the pet react throughout the day.
  Why: this expresses the full concept without expanding into a general wellness tracker.
- The default value proposition is a balanced workday, not "do more work."
  Why: the concept is differentiated by healthier pacing, not just Pomodoro efficiency.
- The pet's visible state should directly reflect user habits through a small set of understandable needs:
  - Mood improves with balanced care and completed routines.
  - Energy responds to work and rest rhythm.
  - Hydration and happiness cues react to water and movement habits.
  Why: users need a clear cause-and-effect link between their actions and the pet.
- Tone should be playful and supportive. The pet can be disappointed or sluggish, but not shaming, punitive, or "dead."
  Why: the app should motivate through attachment, not guilt.

## MVP Behaviors And User-Facing Surfaces
- Minimal onboarding should introduce the pet, explain the daily loop, and start with sensible defaults.
  Why: setup friction would weaken the companion feel before value is shown.
- Structured defaults should be opinionated out of the box:
  - Standard focus and break rhythm.
  - Regular water reminders.
  - A movement prompt framed as a short stand-up-and-move break, not a literal outdoor walk requirement.
  Why: the MVP should coach a routine instead of asking users to design one.
- Habit coverage in MVP:
  - Focus sessions.
  - Breaks.
  - Water intake.
  - Short movement breaks.
  Why: these four behaviors fully represent the concept and give the pet meaningful needs.
- Completion model:
  - Focus sessions and timer-driven breaks are recorded through normal use of the timer flow.
  - Water and movement should be prompted with low-friction confirmation.
  - If the user misses the prompt, the app may keep the action available for later confirmation, but should not silently grant full credit.
  Why: this preserves low friction while keeping the pet's state credible.
- Daily success should be defined as a balanced routine, not streaking focus blocks alone.
  Why: the pet should reinforce sustainable behavior, not overwork.
- Progression should stay lightweight:
  - Expressive reactions and animations.
  - Noticeable "doing well" and "needs attention" states.
  - A small sense of growth or bond over time.
  Why: enough progression to create attachment, but not enough to turn MVP into a content-heavy game.

## Explicit MVP Boundaries
- Out of scope:
  - Social features, leaderboards, sharing, or multiplayer care.
  - Multiple pets or collection mechanics.
  - Deep customization and elaborate pet inventories.
  - Harsh punishment systems.
  - Broad wellness tracking beyond focus, breaks, water, and movement.
  Why: each of these adds complexity without helping validate the core habit-companion loop.

## Acceptance Criteria And Validation
- A new user can understand the product in under a minute and start using it immediately.
- A user can complete a full day's loop without needing settings or advanced customization.
- The pet's state changes are easy to interpret from user behavior.
- Missing care actions creates gentle tension, but the experience still feels supportive.
- A good day is visibly different from an unbalanced day in the pet's behavior and overall feedback.
- The product feels meaningfully different from a plain Pomodoro timer because the pet creates emotional stakes.

## Assumptions And Defaults
- Primary audience: solo desk workers doing computer-based focus work.
- Core hook: the pet is the motivation engine; productivity tooling supports that loop.
- Motivation style: supportive, playful, non-judgmental.
- Movement habit default: short movement break.
- Setup default: minimal onboarding with structured routine defaults.
- Scope default: one pet, single-player, simple progression.
- Default interpretation of "walk": any brief stand-up-and-move action that gives the user a physical reset.
