
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_cron;

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
ALTER TABLE t1 REPLICA IDENTITY USING INDEX t1_operation_guid_unique;

CREATE INDEX IF NOT EXISTS t1_idx_state_id ON t1 (state, id);
CREATE INDEX IF NOT EXISTS t1_idx_client_optype ON t1 (client_id, op_type);

CREATE TABLE IF NOT EXISTS t1_p_2025_09 PARTITION OF t1
    FOR VALUES FROM ('2025-09-01 00:00:00+00') TO ('2025-10-01 00:00:00+00');

CREATE TABLE IF NOT EXISTS t1_p_2025_10 PARTITION OF t1
    FOR VALUES FROM ('2025-10-01 00:00:00+00') TO ('2025-11-01 00:00:00+00');

CREATE TABLE IF NOT EXISTS t1_p_2025_11 PARTITION OF t1
    FOR VALUES FROM ('2025-11-01 00:00:00+00') TO ('2025-12-01 00:00:00+00');

CREATE TABLE IF NOT EXISTS t1_p_2025_12 PARTITION OF t1
    FOR VALUES FROM ('2025-12-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');

ALTER TABLE t1_p_2025_09 REPLICA IDENTITY FULL;
ALTER TABLE t1_p_2025_10 REPLICA IDENTITY FULL;
ALTER TABLE t1_p_2025_11 REPLICA IDENTITY FULL;
ALTER TABLE t1_p_2025_12 REPLICA IDENTITY FULL;

CREATE OR REPLACE FUNCTION t1_generate_data(p_start timestamptz, p_end timestamptz, p_rows bigint)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    ts timestamptz;
    diff interval := p_end - p_start;
    client_cnt int := 500;
	i bigint := 0;
BEGIN
    RAISE NOTICE 'Genarating % rows з % до %', p_rows, p_start, p_end;
    WHILE i < p_rows LOOP
        INSERT INTO t1 (event_date, amount, state, operation_guid, message)
        SELECT
            p_start + (random() * extract(epoch FROM diff)) * interval '1 second',
            (trunc((random()*10000)::numeric * 100) / 100)::numeric(14,2) as amount,
            0::smallint as state,
            gen_random_uuid() as operation_guid, --TODO: add onconflict
            jsonb_build_object('account_number', lpad((trunc(random()*1000000)+1)::text,10,'0'),
                               'client_id', (trunc(random()*client_cnt)+1)::int,
                               'op_type', (CASE WHEN random() < 0.5 THEN 'online' ELSE 'offline' END)
                               ) as message
        FROM generate_series(1, LEAST(1000, p_rows - i));

        i := i + LEAST(1000, p_rows - i);
        IF (i % 10000) = 0 THEN
            RAISE NOTICE 'Inserted % rows', i;
        END IF;
    END LOOP;
    RAISE NOTICE 'Generating is finished. Inserted % rows', i;
END; $$;

SELECT t1_generate_data('2025-09-01 00:00:00+00', '2025-12-31 23:59:59+00', 100000);

CREATE OR REPLACE FUNCTION t1_insert_row()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO t1 (event_date, amount, state, operation_guid, message)
    VALUES (
        now(),
        (trunc((random()*10000)::numeric * 100) / 100)::numeric(14,2),
        0,
        gen_random_uuid(),
        jsonb_build_object(
            'account_number', lpad((trunc(random()*1000000)+1)::text,10,'0'),
            'client_id', (trunc(random()*500)+1)::int,
            'op_type', CASE WHEN random() < 0.5 THEN 'online' ELSE 'offline' END
        )
    );
END;
$$;

SELECT cron.schedule('insert_every_5_sec', '5 seconds', $$ SELECT t1_insert_row(); $$);

CREATE OR REPLACE FUNCTION t1_flip_state()
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    sec int;
BEGIN
    sec := extract(epoch FROM now())::int;
    
    UPDATE t1
    SET state = 1
    WHERE state = 0 AND (id % 2 = sec % 2);
END;
$$;

SELECT cron.schedule(
    'flip_state_every_3_sec',
    '3 seconds',
    $$ SELECT t1_flip_state(); $$
);

CREATE MATERIALIZED VIEW IF NOT EXISTS t1_sum_by_client_op AS
SELECT
    client_id,
    op_type,
    SUM(amount) AS total_amount
FROM t1
WHERE state = 1
GROUP BY client_id, op_type;

CREATE UNIQUE INDEX IF NOT EXISTS t1_sum_by_client_op_idx
ON t1_sum_by_client_op (client_id, op_type);

CREATE OR REPLACE FUNCTION t1_update_sum_trigger()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY t1_sum_by_client_op;
    RETURN NULL;
END;
$$;

CREATE TRIGGER t1_after_state_update
AFTER UPDATE OF state ON t1
FOR EACH STATEMENT
EXECUTE FUNCTION t1_update_sum_trigger();

CREATE ROLE replicator WITH LOGIN PASSWORD 'replicator';
ALTER ROLE replicator REPLICATION;
GRANT CONNECT ON DATABASE postgres TO replicator;

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT inhrelid::regclass AS child FROM pg_inherits WHERE inhparent = 't1'::regclass LOOP
        EXECUTE format('GRANT SELECT ON %I TO replicator', r.child);
    END LOOP;
END $$;


CREATE PUBLICATION t1_publication FOR TABLE t1;
