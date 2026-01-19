#!/bin/bash

set -e

rm -f /app/tmp/pids/server.pid

echo "Checking database connection..."
until pg_isready -h db -U postgres; do
  echo "Waiting for database..."
  sleep 2
done

echo "Database is ready!"

if ! RAILS_ENV=${RAILS_ENV:-development} bundle exec rails db:version > /dev/null 2>&1; then
  echo "Creating database..."
  bundle exec rails db:create
  echo "Running migrations..."
  bundle exec rails db:migrate
  echo "Loading seeds..."
  bundle exec rails db:seed
else
  echo "Database already exists. Running migrations..."
  bundle exec rails db:migrate
fi

exec "$@"
