abstract class PomodoroFailure implements Exception {
  const PomodoroFailure(this.message, [this.cause, this.stackTrace]);

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
}

class PomodoroPersistenceFailure extends PomodoroFailure {
  const PomodoroPersistenceFailure(
    super.message, [
    super.cause,
    super.stackTrace,
  ]);
}

class PomodoroCorruptStateFailure extends PomodoroFailure {
  const PomodoroCorruptStateFailure(
    super.message, [
    super.cause,
    super.stackTrace,
  ]);
}
