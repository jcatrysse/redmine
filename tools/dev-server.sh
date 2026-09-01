#!/usr/bin/env bash
# Bring up a real Redmine instance to verify a feature in a browser.
#
#   tools/dev-server.sh [/path/to/redmine/worktree]
#
# Idempotent. Prints the URL and credentials when the server answers 200.
# Stop it with: tools/dev-server.sh --stop
#
# Every step here was established by running it; the traps are in
# docs/runbook.md.

set -uo pipefail

PORT="${PORT:-3000}"
PIDFILE="/tmp/redmine-dev-$PORT.pid"
LOGFILE="/tmp/redmine-dev-$PORT.log"
FILES="${REDMINE_DEV_FILES:-/tmp/redmine-dev-files}"
DB="${REDMINE_DEV_DB:-redmine_dev}"
PASSWORD="${REDMINE_ADMIN_PASSWORD:-GEOxyzDev123!}"

if [ "${1:-}" = "--stop" ]; then
  [ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null && echo "stopped"
  rm -f "$PIDFILE"
  exit 0
fi

# Resolve the tools directory BEFORE changing directory: $BASH_SOURCE is
# relative, so computing it afterwards silently yields the wrong path and
# dev-seed.rb is not found.
TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO="${1:-/home/user/redmine}"
cd "$REPO" || { echo "FAIL  no such worktree: $REPO" >&2; exit 2; }

echo "==> PostgreSQL"
service postgresql start >/dev/null 2>&1 || pg_ctlcluster 16 main start >/dev/null 2>&1
for i in $(seq 1 20); do pg_isready -q && break; sleep 1; done
pg_isready -q || { echo "FAIL  PostgreSQL did not come up" >&2; exit 1; }
su postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='redmine'\"" 2>/dev/null | grep -q 1 ||
  su postgres -c "psql -q -c \"CREATE USER redmine WITH PASSWORD 'redmine' SUPERUSER;\"" >/dev/null 2>&1
su postgres -c "psql -tAc \"SELECT 1 FROM pg_database WHERE datname='$DB'\"" 2>/dev/null | grep -q 1 ||
  su postgres -c "psql -q -c 'CREATE DATABASE $DB OWNER redmine;'" >/dev/null 2>&1

# The Gemfile reads config/database.yml to decide which database gems to load,
# so this has to exist before bundle install, not after.
if [ ! -f config/database.yml ]; then
  echo "==> config/database.yml"
  cat > config/database.yml <<YAML
development:
  adapter: postgresql
  database: $DB
  host: localhost
  username: redmine
  password: redmine
  encoding: utf8
test:
  adapter: postgresql
  database: redmine_test
  host: localhost
  username: redmine
  password: redmine
  encoding: utf8
YAML
fi

# The dev database is shared between worktrees but `files/` is not, so an
# attachment uploaded while one worktree served the app is unreadable from the
# next one and silently disappears from anything that checks Attachment#readable?.
# Point every worktree at one storage directory instead.
if [ ! -f config/configuration.yml ]; then
  echo "==> config/configuration.yml"
  mkdir -p "$FILES"
  cat > config/configuration.yml <<YAML
default:
  attachments_storage_path: $FILES
YAML
fi

echo "==> gems"
bundle install --jobs 4 >/dev/null 2>&1 || { echo "FAIL  bundle install" >&2; exit 1; }

# There is no rake binstub in this bundle: use `bundle exec ruby bin/rails`.
echo "==> migrate"
RAILS_ENV=development bundle exec ruby bin/rails db:migrate >/dev/null 2>&1 ||
  { echo "FAIL  db:migrate" >&2; exit 1; }

RAILS_ENV=development bundle exec ruby bin/rails runner \
  'exit(Tracker.any? ? 0 : 1)' >/dev/null 2>&1 || {
  echo "==> default data"
  RAILS_ENV=development REDMINE_LANG=en bundle exec ruby bin/rails redmine:load_default_data >/dev/null 2>&1
}

echo "==> seed"
REDMINE_ADMIN_PASSWORD="$PASSWORD" RAILS_ENV=development \
  bundle exec ruby bin/rails runner "$TOOLS/dev-seed.rb" 2>&1 | grep -v '^\s*from ' | tail -2

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "==> already running (pid $(cat "$PIDFILE"))"
else
  echo "==> server on port $PORT"
  mkdir -p tmp/pids log
  nohup env RAILS_ENV=development bundle exec ruby bin/rails server \
    -b 127.0.0.1 -p "$PORT" > "$LOGFILE" 2>&1 &
  echo $! > "$PIDFILE"
fi

for i in $(seq 1 40); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/" 2>/dev/null)" = "200" ] && break
  sleep 3
done
if [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/" 2>/dev/null)" != "200" ]; then
  echo "FAIL  server did not answer 200 — see $LOGFILE" >&2
  tail -20 "$LOGFILE" >&2
  exit 1
fi

cat <<TXT

PASS  http://127.0.0.1:$PORT
      admin / $PASSWORD
      project: geoxyz-verify (subproject geoxyz-verify-sub)
      log: $LOGFILE     stop: tools/dev-server.sh --stop
TXT
