CREATE TABLE sessions
(
    id TEXT PRIMARY KEY,
    owner_id UUID NOT NULL DEFAULT auth.uid(),
    day_key TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('focus', 'break')),
    planned_duration_seconds INTEGER NOT NULL,
    state TEXT NOT NULL CHECK (state IN ('active', 'paused', 'ended')),
    outcome TEXT CHECK (outcome IN ('completed', 'stopped')),
    started_at TEXT NOT NULL,
    last_resumed_at TEXT NOT NULL,
    paused_at TEXT,
    ended_at TEXT,
    remaining_seconds_at_pause INTEGER
);

CREATE TABLE wellness_events
(
    id TEXT PRIMARY KEY,
    owner_id UUID NOT NULL DEFAULT auth.uid(),
    day_key TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('hydration', 'movement')),
    occurred_at TEXT NOT NULL
);

CREATE TABLE daily_activity_summary
(
    id TEXT PRIMARY KEY,
    owner_id UUID NOT NULL DEFAULT auth.uid(),
    day_key TEXT NOT NULL,
    ended_focus_count INTEGER NOT NULL DEFAULT 0,
    ended_break_count INTEGER NOT NULL DEFAULT 0,
    hydration_count INTEGER NOT NULL DEFAULT 0,
    movement_count INTEGER NOT NULL DEFAULT 0,
    last_hydration_at TEXT,
    hydration_timer_anchor_at TEXT NOT NULL,
    hydration_reminder_active INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL,
    CONSTRAINT daily_activity_summary_owner_day_key_unique UNIQUE (owner_id, day_key)
);

CREATE INDEX sessions_owner_day_key_idx ON sessions(owner_id, day_key);
CREATE INDEX sessions_owner_state_idx ON sessions(owner_id, state);
CREATE INDEX wellness_events_owner_day_key_idx ON wellness_events(owner_id, day_key);
CREATE INDEX daily_activity_summary_owner_day_key_idx ON daily_activity_summary(owner_id, day_key);

ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE wellness_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_activity_summary ENABLE ROW LEVEL SECURITY;

CREATE POLICY sessions_select_own
    ON sessions
    FOR SELECT
    TO authenticated
    USING (owner_id = auth.uid());

CREATE POLICY sessions_insert_own
    ON sessions
    FOR INSERT
    TO authenticated
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY sessions_update_own
    ON sessions
    FOR UPDATE
    TO authenticated
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY sessions_delete_own
    ON sessions
    FOR DELETE
    TO authenticated
    USING (owner_id = auth.uid());

CREATE POLICY wellness_events_select_own
    ON wellness_events
    FOR SELECT
    TO authenticated
    USING (owner_id = auth.uid());

CREATE POLICY wellness_events_insert_own
    ON wellness_events
    FOR INSERT
    TO authenticated
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY wellness_events_update_own
    ON wellness_events
    FOR UPDATE
    TO authenticated
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY wellness_events_delete_own
    ON wellness_events
    FOR DELETE
    TO authenticated
    USING (owner_id = auth.uid());

CREATE POLICY daily_activity_summary_select_own
    ON daily_activity_summary
    FOR SELECT
    TO authenticated
    USING (owner_id = auth.uid());

CREATE POLICY daily_activity_summary_insert_own
    ON daily_activity_summary
    FOR INSERT
    TO authenticated
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY daily_activity_summary_update_own
    ON daily_activity_summary
    FOR UPDATE
    TO authenticated
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY daily_activity_summary_delete_own
    ON daily_activity_summary
    FOR DELETE
    TO authenticated
    USING (owner_id = auth.uid());

ALTER TABLE sessions REPLICA IDENTITY FULL;
ALTER TABLE wellness_events REPLICA IDENTITY FULL;
ALTER TABLE daily_activity_summary REPLICA IDENTITY FULL;
