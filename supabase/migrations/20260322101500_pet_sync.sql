CREATE TABLE pet_sessions
(
    id TEXT PRIMARY KEY,
    owner_id UUID NOT NULL DEFAULT auth.uid(),
    animal_id TEXT NOT NULL,
    bio_name TEXT NOT NULL,
    bio_summary TEXT NOT NULL,
    latest_speech TEXT NOT NULL,
    latest_event_id TEXT,
    last_error TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    CONSTRAINT pet_sessions_owner_unique UNIQUE (owner_id)
);

CREATE TABLE pet_events
(
    id TEXT PRIMARY KEY,
    owner_id UUID NOT NULL DEFAULT auth.uid(),
    pet_session_id TEXT NOT NULL,
    event_type TEXT NOT NULL CHECK (
        event_type IN (
            'start_focus_session',
            'complete_focus_session',
            'stop_focus_session_early',
            'start_break',
            'complete_break',
            'stop_break_early',
            'pet_pet',
            'drink_water',
            'move_or_stretch'
        )
    ),
    source_device TEXT NOT NULL CHECK (source_device IN ('macos', 'ios')),
    status TEXT NOT NULL CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    reaction_speech TEXT,
    error_message TEXT,
    created_at TEXT NOT NULL,
    claimed_at TEXT,
    completed_at TEXT
);

CREATE INDEX pet_sessions_owner_updated_idx ON pet_sessions(owner_id, updated_at);
CREATE INDEX pet_events_owner_status_created_idx ON pet_events(owner_id, status, created_at);
CREATE INDEX pet_events_owner_session_created_idx ON pet_events(owner_id, pet_session_id, created_at);

ALTER TABLE pet_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE pet_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY pet_sessions_select_own
    ON pet_sessions
    FOR SELECT
    TO authenticated
    USING (owner_id = auth.uid());

CREATE POLICY pet_sessions_insert_own
    ON pet_sessions
    FOR INSERT
    TO authenticated
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY pet_sessions_update_own
    ON pet_sessions
    FOR UPDATE
    TO authenticated
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY pet_sessions_delete_own
    ON pet_sessions
    FOR DELETE
    TO authenticated
    USING (owner_id = auth.uid());

CREATE POLICY pet_events_select_own
    ON pet_events
    FOR SELECT
    TO authenticated
    USING (owner_id = auth.uid());

CREATE POLICY pet_events_insert_own
    ON pet_events
    FOR INSERT
    TO authenticated
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY pet_events_update_own
    ON pet_events
    FOR UPDATE
    TO authenticated
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY pet_events_delete_own
    ON pet_events
    FOR DELETE
    TO authenticated
    USING (owner_id = auth.uid());

ALTER TABLE pet_sessions REPLICA IDENTITY FULL;
ALTER TABLE pet_events REPLICA IDENTITY FULL;
