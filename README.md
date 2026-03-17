# flutter_pomodoro

Flutter Pomodoro application scaffold.

## Engineering Workflow

Project governance lives in [`.specify/memory/constitution.md`](.specify/memory/constitution.md).
All implementation decisions, specs, and reviews are expected to follow it.

Before merging a change, run:

- `dart format .`
- `flutter analyze`
- `flutter test`
- `flutter test integration_test` when timer lifecycle, navigation, or other
  end-to-end behavior changes

## Implementation Expectations

- Keep timer logic and state transitions out of large widget trees.
- Reuse shared theme tokens and components before introducing custom UI patterns.
- Define loading, empty, error, and success states for user-facing changes.
- Treat performance as a requirement for timer accuracy, animations, startup, and
  scrolling behavior.

## Getting Started

Useful Flutter references:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)
- [Flutter documentation](https://docs.flutter.dev/)
