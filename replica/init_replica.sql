CREATE TABLE IF NOT EXISTS t1 (
    event_date timestamptz NOT NULL,
    id bigserial NOT NULL,
    amount numeric(14,2) NOT NULL DEFAULT 0,
    state smallint NOT NULL DEFAULT 0,
    operation_guid uuid NOT NULL,
    message jsonb NOT NULL,
    client_id int GENERATED ALWAYS AS ((message->>'client_id')::int) STORED,
    op_type text GENERATED ALWAYS AS (message->>'op_type') STORED,
    created_at timestamptz NOT NULL DEFAULT now()
) PARTITION BY RANGE (event_date);

ALTER TABLE t1 ADD CONSTRAINT t1_operation_guid_unique UNIQUE (event_date, operation_guid);

CREATE INDEX IF NOT EXISTS t1_idx_state_id ON t1 (state, id);
CREATE INDEX IF NOT EXISTS t1_idx_client_optype ON t1 (client_id, op_type);

DO $$
DECLARE
    start_date DATE := DATE '2025-09-01';
    end_date   DATE := DATE '2026-01-01';
    current DATE := start_date;
    next_date DATE;
    partition_name TEXT;
BEGIN
    WHILE current < end_date LOOP
        next_date := (current + INTERVAL '1 month')::DATE;
        partition_name := format('t1_p_%s', to_char(current, 'YYYY_MM'));

        EXECUTE format($f$
            CREATE TABLE IF NOT EXISTS %I PARTITION OF t1
            FOR VALUES FROM ('%s 00:00:00+00') TO ('%s 00:00:00+00');
        $f$, partition_name, current, next_date);

        EXECUTE format($f$
            ALTER TABLE %I REPLICA IDENTITY FULL;
        $f$, partition_name);

        current := next_date;
    END LOOP;
END $$;