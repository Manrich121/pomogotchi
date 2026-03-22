# Contract: Main Screen UI

## Purpose

Define the user-facing behavior of the single-screen Pomogotchi interface so implementation and tests share the same contract.

## Screen Regions

- **Timer Header**: Shows the current session label and remaining time.
- **Primary Action Area**: Exposes the main start, pause, resume, or stop actions for the current session state.
- **Completion Prompt Area**: Shows completed-session feedback and the call to begin the fixed 10-minute break after focus completion.
- **Daily Summary Area**: Shows ended focus count, ended break count, hydration count, and movement count for the current day.
- **Reminder Area**: Shows a visible hydration reminder when the in-app threshold has been reached.

## Screen States

| State | Timer Label | Primary Actions | Completion Prompt | Reminder Behavior |
|-------|-------------|-----------------|-------------------|-------------------|
| Loading | App name or loading indicator | None | Hidden | Hidden |
| Idle |
| Focus Active | `Focus session` with decreasing time | `Pause`, `Stop` | Hidden | May appear without interrupting timer |
| Focus Paused | `Focus paused` with frozen time | `Resume`, `Stop` | Hidden | May remain visible |
| Focus Completed Prompt | `Focus complete` with `00:00` | `Start break` and `Reset` or equivalent return-to-idle action | Visible | May remain visible until hydration is logged |
| Break Active | `Break session` with decreasing time | `Pause`, `Stop` | Hidden | May appear without interrupting timer |
| Break Paused | `Break paused` with frozen time | `Resume`, `Stop` | Hidden | May remain visible |
| Error | Last known state if available | `Retry` plus safe return action | Hidden | Hidden unless data can still be shown safely |

## Interaction Contract

- Starting focus from idle begins a fixed 40-minute session immediately.
- Pausing freezes the remaining time exactly where it is shown.
- Stopping a session ends it immediately, returns to idle, and increments the matching daily total.
- Completing a focus session shows a completion indicator and a clear `Start break` call to action.
- Completing a break session returns the screen to idle with the next focus session ready.
- Logging hydration or movement is always a one-tap action from the main screen and must not interrupt an active timer.

## Accessibility Contract

- The timer value must expose a semantics label that includes session type and remaining time.
- Primary actions must expose descriptive labels such as `Start focus session`, `Pause session`, `Resume session`, `Stop session`, and `Start break session`.
- Hydration and movement actions must expose labels that describe the logged event.
- Focus order must remain predictable across timer, actions, summary, and reminder regions.

## Error Handling Contract

- If persisted state cannot be restored, show a safe idle screen or dedicated error state with a retry path.
- Error messaging must not hide the user's ability to start a new focus session if state recovery fails.
- The screen must never show both a completed-session prompt and an active timer simultaneously.
