# Pomogotchi MVP UX Wireframes And Screen Definition

## Summary
This document defines the MVP user experience surfaces for Pomogotchi so wireframing can begin without reopening product scope. It translates the existing product spec and technical plan into concrete screens, glanceable surfaces, and state-driven layouts for macOS and iPhone.

The goal of this artifact is to answer:
- What are the MVP screens and surfaces?
- What must each screen show and allow the user to do?
- Which states need explicit wireframes?
- How does the pet-transfer ritual work across Mac and iPhone?

## UX Principles
- The pet is the emotional anchor, not decoration around a timer.
- The macOS app is the user's home base during work.
- The iPhone app is a companion surface used mainly during movement breaks.
- The user should understand the current state in under three seconds.
- Core actions should always be one tap or one click away.
- Missing habits should create gentle tension, not guilt.
- Glanceable surfaces should communicate status, not replace the main interaction flow.

## MVP Surface Inventory
### macOS primary surfaces
- Onboarding window
- Menu bar icon states
- Menu bar popover home state
- Active focus session state
- Break prompt and transfer state
- Pet-away state while the pet is on iPhone
- Daily summary and history window
- Minimal settings window

### iPhone companion surfaces
- Transfer arrival screen
- Active movement break screen
- Hydration check-in screen or inline card
- Return-to-Mac confirmation screen

### Glanceable system surfaces
- iPhone Live Activity
- iPhone Home Screen widget
- macOS menu bar icon state variations
- Local notification layouts and actions

## Navigation Model
### macOS
- Primary entry point: menu bar icon opens the popover.
- Secondary window exists for onboarding, history, and settings only.
- The popover should handle the full daily loop without forcing users into a larger window.

### iPhone
- Primary entry point: deep link from transfer prompt, notification, widget, or Live Activity.
- The companion app should open directly into the current break state, not a dashboard.
- The iPhone experience should feel like a focused temporary mode, not a second primary product.

## Screen Definitions
## 1. macOS onboarding window
### Purpose
Introduce the pet, explain the daily loop, and get the user into the first focus session quickly.

### Must show
- Pet introduction and core promise
- Short explanation of focus, breaks, water, and movement
- Default work rhythm summary
- Sign in with Apple entry point
- Primary action to start

### Must allow
- Start with defaults
- Optional review of reminder preferences

### Wireframe states
- First launch
- Sign-in in progress
- Onboarding complete

## 2. macOS menu bar popover: home and idle state
### Purpose
Serve as the main home screen during the workday.

### Must show
- Pet visual and current mood cue
- Current status line from the pet
- Next recommended action
- Focus timer card with default session length
- Daily progress snapshot:
  - focus sessions completed
  - water check-ins
  - movement breaks
  - overall balance

### Must allow
- Start focus session
- Log water
- Open movement break flow if relevant
- Open history
- Open settings

### Layout priority
- Pet and status first
- Primary next action second
- Progress summary third
- Secondary utilities last

## 3. macOS active focus session state
### Purpose
Support the main work interval without overwhelming the user.

### Must show
- Countdown timer
- Pet focus animation or behavior
- Current session status
- Quick progress indicators for the day
- Next break expectation

### Must allow
- Pause session
- End session early
- Mark interruption reason if ended early

### Wireframe states
- Session running
- Session paused
- Session nearing completion
- Session completed

## 4. macOS break prompt and transfer state
### Purpose
Create the emotional handoff moment when the pet invites the user to step away.

### Must show
- Session completion feedback from the pet
- Recommended next break type
- Clear invitation to transfer the pet to iPhone for a movement break
- Secondary option to keep the break on Mac for a short rest break

### Must allow
- Transfer pet to iPhone
- Start a short non-transfer break
- Snooze briefly

### Wireframe states
- Standard short-break prompt
- Movement-break prompt
- Transfer in progress
- Transfer failed

## 5. macOS pet-away state
### Purpose
Make the transfer feel real by showing the pet is temporarily away from the Mac.

### Must show
- Clear away-state message
- Last known pet status
- Break timer or expected return cue
- Limited daily progress view

### Must allow
- View current break status
- Nudge the return flow if needed
- Avoid starting a normal focus session until return is resolved

### Wireframe states
- Pet on iPhone and active
- Waiting for return
- Return interrupted or offline recovery

## 6. macOS daily summary and history window
### Purpose
Provide lightweight reflection and explain the pet's recent behavior.

### Must show
- Today's completed routine summary
- Pet mood and bond change
- Short reflection or end-of-day message
- Recent daily summaries

### Must allow
- Review today
- Review recent days
- Understand what improved or hurt the pet's condition

### Keep out of scope
- Deep analytics
- Gamified charts
- Complex journaling

## 7. macOS settings window
### Purpose
Support minor adjustments without turning settings into a product area.

### Must show
- Focus and break durations
- Water reminder cadence
- Notification preferences
- Sign-in and sync status

### Must allow
- Small routine tweaks only
- Notification enablement

### Keep out of scope
- Deep pet customization
- Multiple routines
- Extensive AI controls

## 8. iPhone companion transfer arrival screen
### Purpose
Receive the pet from the Mac and make the break feel immediate.

### Must show
- Arrival transition or pet-handoff moment
- Break type and suggested duration
- Pet message explaining the break
- One clear primary action to begin

### Must allow
- Start movement break
- Confirm water if prompted
- Cancel and return pet if transfer was accidental

## 9. iPhone active movement break screen
### Purpose
Be the main companion-mode screen while the user is away from the desk.

### Must show
- Pet animation or movement behavior
- Break timer or progress indicator
- Encouraging pet message
- Optional lightweight prompts such as "stand up", "stretch", or "take a few steps"

### Must allow
- Confirm movement completed
- Confirm water completed
- End break
- Return pet to Mac

### Layout priority
- Pet presence first
- Break progress second
- One-tap check-ins third
- Return action always visible

## 10. iPhone return-to-Mac confirmation screen
### Purpose
Close the ritual with an intentional handoff back to the user's work context.

### Must show
- Pet acknowledgement of the completed break
- Summary of what was completed
- Clear return-to-Mac action

### Must allow
- Return pet to Mac explicitly
- Delay return briefly if the user is still away

### Wireframe states
- Break completed and ready to return
- Return in progress
- Return failed or offline

## Widget And Live Activity Definitions
## 11. iPhone widget
### Purpose
Provide glanceable awareness and quick re-entry into the companion flow.

### Must show
- Current pet status
- Current high-level routine state:
  - focus happening on Mac
  - break available
  - pet currently on iPhone
- One tap target into the relevant screen

### Widget states to wireframe
- Pet on Mac during focus
- Transfer available
- Pet on iPhone during movement break
- Waiting to return to Mac

## 12. iPhone Live Activity
### Purpose
Keep the active break visible without requiring the app to stay open.

### Must show
- Break timer or progress
- Pet state cue
- Primary current action

### Live Activity states to wireframe
- Movement break active
- Break almost complete
- Ready to return pet to Mac

## 13. Local notifications
### Purpose
Pull the user into the right moment with minimal friction.

### Notification types
- Focus complete
- Break due
- Hydration reminder
- Transfer pet to iPhone
- Return pet to Mac

### Notification actions
- Start break
- Log water
- Open companion app
- Return to Mac
- Snooze

## Critical User Flows To Wireframe End-To-End
- First launch to first focus session
- Idle Mac home to active focus session
- Focus complete to short break on Mac
- Focus complete to movement-break transfer to iPhone
- iPhone movement break to explicit return to Mac
- Hydration reminder from any current state
- Daily summary review at end of day
- Sync interruption or failed transfer recovery

## State Matrix
### Pet state dimensions that need visible treatment
- Mood: thriving, content, needs attention
- Energy: active, neutral, tired
- Hydration cue: satisfied, reminder due
- Location: on Mac, transferring, on iPhone, returning

### Routine states that need explicit layouts
- Idle and ready to focus
- Focus in progress
- Break due
- Short break active on Mac
- Movement break active on iPhone
- Pet away from Mac
- End-of-day summary available

### Failure and recovery states
- Sign-in unavailable
- Sync delayed
- Transfer failed
- AI response fallback used
- Notification permission not granted

## MVP Wireframing Priorities
Wireframe these first:
- macOS home and idle popover
- macOS active focus session
- macOS movement-break transfer prompt
- macOS pet-away state
- iPhone transfer arrival screen
- iPhone active movement break screen
- iPhone return-to-Mac screen
- iPhone widget states
- Live Activity states

Wireframe these second:
- Onboarding
- Daily summary and history
- Settings
- Notification layouts
- Error and recovery states

## Deliverables For The Next Design Step
- Low-fidelity wireframes for each priority screen
- A state-based wireframe set for pet mood, timer state, and transfer status
- A clickable flow for the Mac-to-iPhone movement break ritual
- A compact glanceable-surface sheet for widget, Live Activity, and notifications

## Assumptions And Defaults
- The macOS menu bar popover is the primary everyday surface.
- The iPhone app is a companion mode, not a parallel primary app.
- Only one pet exists in the MVP.
- The transfer ritual should feel emotionally significant and visually obvious.
- Widgets and Live Activity are support surfaces and should not take on full app complexity.
