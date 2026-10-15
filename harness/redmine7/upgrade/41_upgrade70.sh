#!/bin/bash
# Upgrade a copy of the seeded 5.1 database with the 7.0 tree: createdb -T, db:migrate, redmine:plugins:migrate,
# exactly as documented. Every step logs to $LOGS/41_<step>.log; the script stops at the first failure
# (WORKAROUNDS=1 applies the workarounds of 42_workarounds.sh where a step fails and goes on).
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd); . "$D/env.sh"
cd "$U70"
step() { local name=$1; shift; echo "== $name"; "$@" > "$LOGS/41_$name.log" 2>&1; local rc=$?; echo "   exit=$rc"; [ $rc -ne 0 ] && grep -v -E '^/|^\s+/|warning:' "$LOGS/41_$name.log" | grep -v '^$' | head -12; return $rc; }
"$D/23_server51.sh" stop
# the files directory moves with the database
rm -rf "$U70/files"; mkdir -p "$U70/files"; cp -a "$U51/files/." "$U70/files/"
"$D/50_server70.sh" stop 2>/dev/null
dropdb --if-exists r70h_upg70 && createdb -O redmine -T r70h_upg r70h_upg70 || exit 1
psql -d r70h_upg70 -Atc "select version from schema_migrations order by 1" > "$S/schema_migrations_before.txt"
step db_migrate bundle exec rake db:migrate || {
  [ "${WORKAROUNDS:-0}" = 1 ] || exit 1
  "$D/42_workarounds.sh" before_core_retry && step db_migrate_retry bundle exec rake db:migrate || exit 1
}
step plugins_migrate bundle exec rake redmine:plugins:migrate || {
  [ "${WORKAROUNDS:-0}" = 1 ] || exit 1
  "$D/42_workarounds.sh" before_plugins_retry && step plugins_migrate_retry bundle exec rake redmine:plugins:migrate || exit 1
}
psql -d r70h_upg70 -Atc "select version from schema_migrations order by 1" > "$S/schema_migrations_after.txt"
echo "schema_migrations: $(wc -l < "$S/schema_migrations_before.txt") before, $(wc -l < "$S/schema_migrations_after.txt") after"
