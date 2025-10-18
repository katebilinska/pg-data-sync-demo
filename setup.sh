#!/usr/bin/env bash

if ! command -v bash &> /dev/null
then
    echo "bash could not be found. Please run this script in bash (Mac/Linux or Git Bash/WSL on Windows)."
    exit 1
fi

set -e

echo "Starting containers..."
docker-compose up -d --build

echo "Waiting for primary DB..."
until docker exec -i pg_primary pg_isready -U postgres > /dev/null 2>&1; do
    sleep 2
done
echo "Primary DB ready."

echo "Waiting for replica DB..."
until docker exec -i pg_replica pg_isready -U postgres > /dev/null 2>&1; do
    sleep 2
done
echo "Replica DB ready."

echo "Waiting for replication connection..."
until docker exec -e PGPASSWORD=replicator -i pg_replica psql -h pg_primary -U replicator -d postgres -c '\q'; do
    echo "Primary DB not ready for replication, waiting..."
    sleep 2
done
echo "Replication connection ready."

echo "Creating subscription..."
docker cp ./replica/create_subscription.sql pg_replica:/tmp/create_subscription.sql
docker exec -i pg_replica psql -U postgres -d postgres -f /tmp/create_subscription.sql

echo "Setup complete!"
