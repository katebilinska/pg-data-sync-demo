# Postgres Data Synchronization Demo

This repository demonstrates a PostgreSQL setup with:

- Logical replication (primary → replica)
- Table partitioning
- Triggers and materialized views
- Scheduled tasks (pg_cron)

---

## Folder Structure

- **primary/**: Contains the Dockerfile and SQL initialization for the primary database.
- **replica/**: Contains the Dockerfile, SQL initialization for the replica, and subscription creation.
- **setup.sh**: Orchestrates the setup of containers, replication, and subscription.
- **docker-compose.yml**: Defines the primary and replica services.

---

## Setup Instructions

### Prerequisites

- Docker
- Docker Compose
- Bash shell (Mac/Linux, or Git Bash / WSL on Windows)

### Steps

1. Clone the repository:

```bash
git clone https://github.com/katebilinska/pg-data-sync-demo.git
cd pg-data-sync-demo
```

2. Run the setup script:
```bash
bash setup.sh
```

This will:
- Build and start the Docker containers
- Wait until the primary and replica databases are ready
- Establish replication connection
- Create the subscription from primary to replica

3. Verify replication:
   
- Connect to the replica database on port 5434
- Check that data from the primary database is replicated

---

## Notes

- The primary database listens on port 5433.
- The replica database listens on port 5434.
- The create_subscription.sql file is copied to the replica during setup.
- The t1 table is partitioned by event_date and has a materialized view t1_sum_by_client_op updated via trigger

---

## License

This project is for demonstration purposes.
