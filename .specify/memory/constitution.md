<!--
Sync Impact Report
Version change: template -> 1.0.0
Modified principles:
- Template Principle 1 -> I. Quality Is a Product Requirement
- Template Principle 2 -> II. UX Consistency Is Mandatory
- Template Principle 3 -> III. Test the Behavior That Matters
- Template Principle 4 -> IV. Performance Must Be Measured
- Template Principle 5 -> V. Technical Decisions Follow Product Value
Added sections:
- Engineering Standards
- Delivery Workflow
Removed sections:
- None
Templates requiring updates:
- ✅ .specify/templates/plan-template.md
- ✅ .specify/templates/spec-template.md
- ✅ .specify/templates/tasks-template.md
- ✅ .specify/templates/agent-file-template.md
- ✅ README.md
- ⚠ pending .specify/templates/commands/*.md (directory not present in this repository)
Follow-up TODOs:
- None
-->
# flutter_pomodoro Constitution

## Core Principles

### I. Quality Is a Product Requirement
All production changes MUST leave the codebase formatted, analyzable, and easy to
review. Business logic, timer calculations, and state transitions MUST live outside
large widget trees and be implemented as small, composable units with clear ownership.
New packages, architectural layers, or generated code MUST be justified in the
relevant spec or plan, including the simpler alternative that was rejected. Work that
meets feature acceptance but weakens maintainability, static analysis, or
debuggability is incomplete.

Rationale: A timer app depends on predictable state and fast iteration; poor code
quality becomes a product defect quickly.

### II. UX Consistency Is Mandatory
Every user-facing flow MUST reuse shared theme tokens, navigation patterns, copy tone,
and common components before introducing bespoke UI. Each impacted screen or component
MUST define loading, empty, error, and success states when those states can occur, and
interactive elements MUST expose accessible labels, predictable focus order, and touch
targets appropriate for mobile devices. A new interaction pattern or visual language
may be introduced only when the existing system cannot meet the requirement and the
reason is documented.

Rationale: Consistency reduces cognitive load and keeps the application trustworthy
across repeated daily use.

### III. Test the Behavior That Matters
Every change to business logic, state management, or user-visible behavior MUST add or
update automated tests at the lowest useful level. Pure logic MUST be covered with unit
tests, reusable UI behavior MUST be covered with widget or golden tests when visual
regressions matter, and critical end-to-end journeys such as starting, pausing,
resuming, and completing timers MUST use integration coverage when changed. If a change
cannot be covered with automation, the limitation and required manual verification MUST
be documented in the plan and review record. Defects found without a protecting test
MUST add one as part of the fix.

Rationale: Flutter regressions usually appear in state transitions and interaction
details; targeted tests are the fastest way to preserve confidence.

### IV. Performance Must Be Measured
The application MUST protect smooth interaction on target devices by avoiding
synchronous work on the UI thread that risks frame drops, by lazily building long
collections, and by keeping rebuild scopes intentional. Any feature that can affect
startup, animation, navigation, timer accuracy, background behavior, or large-list
rendering MUST define measurable performance expectations in the spec and include
profiling or instrumentation before merge. Work that risks frame drops, timer drift, or
excessive battery usage is incomplete until the risk is measured and addressed.

Rationale: Pomodoro flows are repetitive and time-sensitive, so users notice timing
drift and jank immediately.

### V. Technical Decisions Follow Product Value
Technical decisions MUST be made by evaluating, in order, user impact, consistency with
existing architecture, performance cost, and long-term maintenance burden. The default
choice MUST be the simplest solution that satisfies the requirement and this
constitution; speculative abstractions, duplicate state sources, and dependency
additions without a documented need are prohibited. When multiple options remain,
choose the one that is easiest to test, easiest to explain, and easiest to reverse.

Rationale: Clear decision rules prevent accidental complexity and keep implementation
choices aligned with the product.

## Engineering Standards

- Application code MUST live in `lib/`, organized by feature or shared app modules once
  the scaffold grows beyond a single file.
- Platform runner code under `android/`, `ios/`, `macos/`, and
  `web/` MUST remain close to generated defaults unless a platform-specific requirement
  demands customization.
- `dart format .`, `flutter analyze`, and all automated tests relevant to the change
  MUST pass before merge.
- Shared visual tokens, reusable widgets, strings, and timer-domain rules MUST be
  centralized instead of duplicated across screens.
- Dependencies SHOULD prefer Flutter SDK capabilities or well-supported ecosystem
  packages; abandoned, redundant, or overlapping packages MUST not be introduced.
- Feature specifications MUST state accessibility expectations and measurable
  performance requirements for critical flows.

## Delivery Workflow

1. Every feature MUST begin with a spec that captures user stories, acceptance
   criteria, UX states, accessibility needs, and performance expectations.
2. Every implementation plan MUST include a Constitution Check covering architecture,
   testing, UX consistency, and performance risk before coding starts.
3. Implementation MUST proceed in small increments with tests written before or
   alongside code, and risky UI or timing changes MUST be profiled before completion.
4. Reviews MUST verify semantics, state boundaries, error handling, rebuild-sensitive
   code paths, dependency justification, and whether a simpler design was rejected for
   explicit reasons.
5. Release readiness MUST include updated docs when user behavior changes and manual QA
   notes for device-specific, notification, or background-timing behavior when
   automation is insufficient.

## Governance

This constitution overrides conflicting local habits, generated defaults, and template
examples. Amendments require a documented problem statement, the proposed constitutional
change, updates to dependent templates and guidance in the same change, and approval
from project maintainers before implementation continues under the new rule.

Versioning policy for this constitution MUST follow semantic versioning. MAJOR versions
remove or redefine a principle or governance guarantee. MINOR versions add a principle,
new mandatory section, or materially expand an obligation. PATCH versions clarify
existing guidance without changing the expected engineering behavior.

Compliance review is mandatory for every spec, plan, task list, and code review.
Exceptions MUST be time-boxed, documented with rationale, and tracked as follow-up work
before release. When technical speed conflicts with these principles, the constitution
remains the source of truth until it is explicitly amended. `README.md` and generated
agent guidance may explain how to execute the work, but they MUST stay consistent with
this document.

**Version**: 1.0.0 | **Ratified**: 2026-03-16 | **Last Amended**: 2026-03-16
