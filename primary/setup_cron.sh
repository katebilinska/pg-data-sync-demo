#!/bin/bash
set -e

until pg_isready -U postgres; do
  echo "Waiting for PostgreSQL to start..."
  sleep 2
done

echo "PostgreSQL is up. Setting up pg_cron tasks..."

psql -U postgres -d postgres -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"

echo "pg_cron setup completed."
