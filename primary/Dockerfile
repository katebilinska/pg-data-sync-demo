FROM postgres:14

RUN apt-get update && \
    apt-get install -y postgresql-14-cron && \
    rm -rf /var/lib/apt/lists/*

RUN echo "shared_preload_libraries = 'pg_cron'" >> /usr/share/postgresql/postgresql.conf.sample
RUN echo "cron.database_name = 'postgres'" >> /usr/share/postgresql/postgresql.conf.sample

COPY init_primary.sql /docker-entrypoint-initdb.d/

EXPOSE 5432
