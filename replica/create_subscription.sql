CREATE SUBSCRIPTION t1_subscription
CONNECTION 'host=pg_primary port=5432 dbname=postgres user=replicator password=replicator'
PUBLICATION t1_publication
WITH (create_slot = true, slot_name = 't1_slot', copy_data = true);