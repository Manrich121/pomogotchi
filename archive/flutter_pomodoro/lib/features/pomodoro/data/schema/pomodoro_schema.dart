import 'package:powersync/powersync.dart';

const sessionsTable = 'sessions';
const wellnessEventsTable = 'wellness_events';
const dailyActivitySummaryTable = 'daily_activity_summary';

const pomodoroSchema = Schema([
  Table(
    sessionsTable,
    [
      Column.text('day_key'),
      Column.text('type'),
      Column.integer('planned_duration_seconds'),
      Column.text('state'),
      Column.text('outcome'),
      Column.text('started_at'),
      Column.text('last_resumed_at'),
      Column.text('paused_at'),
      Column.text('ended_at'),
      Column.integer('remaining_seconds_at_pause'),
    ],
    indexes: [
      Index('sessions_day_key', [IndexedColumn.ascending('day_key')]),
      Index('sessions_state', [IndexedColumn.ascending('state')]),
      Index('sessions_type', [IndexedColumn.ascending('type')]),
      Index('sessions_started_at', [IndexedColumn.ascending('started_at')]),
    ],
  ),
  Table(
    wellnessEventsTable,
    [Column.text('day_key'), Column.text('type'), Column.text('occurred_at')],
    indexes: [
      Index('wellness_day_key', [IndexedColumn.ascending('day_key')]),
      Index('wellness_type', [IndexedColumn.ascending('type')]),
      Index('wellness_occurred_at', [IndexedColumn.ascending('occurred_at')]),
    ],
  ),
  Table(
    dailyActivitySummaryTable,
    [
      Column.text('day_key'),
      Column.integer('ended_focus_count'),
      Column.integer('ended_break_count'),
      Column.integer('hydration_count'),
      Column.integer('movement_count'),
      Column.text('last_hydration_at'),
      Column.text('hydration_timer_anchor_at'),
      Column.integer('hydration_reminder_active'),
      Column.text('updated_at'),
    ],
    indexes: [
      Index('summary_day_key', [IndexedColumn.ascending('day_key')]),
      Index('summary_updated_at', [IndexedColumn.ascending('updated_at')]),
    ],
  ),
]);
