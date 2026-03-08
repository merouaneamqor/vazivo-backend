#!/bin/sh
# Run db:prepare with retries to avoid ActiveRecord::ConcurrentMigrationError
# when another process is already running migrations (e.g. manual migrate while api starts).
# Then exec the main command (e.g. rails server).

set -e

MIGRATE_MAX_ATTEMPTS=${MIGRATE_MAX_ATTEMPTS:-12}
MIGRATE_RETRY_SLEEP=${MIGRATE_RETRY_SLEEP:-5}

attempt=1
while [ $attempt -le "$MIGRATE_MAX_ATTEMPTS" ]; do
  if bundle exec rails db:prepare 2>/dev/null; then
    break
  fi
  if [ $attempt -eq "$MIGRATE_MAX_ATTEMPTS" ]; then
    echo "WARN: db:prepare failed after $MIGRATE_MAX_ATTEMPTS attempts. Proceeding (migrations may already be applied)."
    bundle exec rails db:prepare || true
    break
  fi
  echo "Migration lock held (attempt $attempt/$MIGRATE_MAX_ATTEMPTS). Retrying in ${MIGRATE_RETRY_SLEEP}s..."
  sleep "$MIGRATE_RETRY_SLEEP"
  attempt=$((attempt + 1))
done

exec "$@"
