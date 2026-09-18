#!/bin/bash

set -e

rm -f /app/tmp/pids/server.pid

echo "Checking database connection..."
until pg_isready -h db -U postgres; do
  echo "Waiting for database..."
  sleep 2
done

echo "Database is ready!"

RAILS_ENV=${RAILS_ENV:-development}
RUN_DB_MIGRATE=${RUN_DB_MIGRATE:-true}

if [ "$RUN_DB_MIGRATE" = "true" ]; then
  if ! RAILS_ENV=${RAILS_ENV} bundle exec rails db:version > /dev/null 2>&1; then
    echo "Creating database..."
    bundle exec rails db:create
    echo "Running migrations..."
    bundle exec rails db:migrate
    if [ "$RAILS_ENV" = "development" ]; then
      echo "Loading seeds..."
      bundle exec rails db:seed
    fi
  else
    echo "Database already exists. Running migrations..."
    bundle exec rails db:migrate
  fi
else
  echo "RUN_DB_MIGRATE=false: skipping database creation/migration."
fi

exec "$@"
