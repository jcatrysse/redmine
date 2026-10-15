#!/bin/bash
# Fresh r70h_upg (production env of the 5.1 tree): core migrations, plugin migrations, default data (en).
# Every step logs to $LOGS/12_<step>.log. Re-runnable: drops r70h_upg first.
# issue_recurring's rake file loads models (redmine_contacts' Deal -> notes table), so every rake task fails
# on an empty database while it is installed: it stays aside until the other plugins are migrated
# (as tools/testenv/setup.sh does).
set -uo pipefail
. "$(dirname "$0")/env.sh"
export PATH=/opt/rbenv/versions/3.2.6/bin:$PATH
cd "$U51"
mkdir -p "$U51/.aside"; AS="$U51/.aside/issue_recurring"
step() { local name=$1; shift; echo "== $name"; "$@" > "$LOGS/12_$name.log" 2>&1; local rc=$?; echo "   exit=$rc"; [ $rc -ne 0 ] && grep -v '^/' "$LOGS/12_$name.log" | head -8; return $rc; }
dropdb --if-exists r70h_upg && createdb -O redmine -E UTF8 -T template0 r70h_upg || exit 1
[ -d plugins/issue_recurring ] && mv plugins/issue_recurring "$AS"
trap '[ -d "$AS" ] && mv "$AS" "$U51/plugins/issue_recurring"' EXIT
step secret bundle exec rake generate_secret_token || exit 1
step migrate bundle exec rake db:migrate || exit 1
step plugins bundle exec rake redmine:plugins:migrate || exit 1
REDMINE_LANG=en step default_data bundle exec rake redmine:load_default_data || exit 1
mv "$AS" plugins/issue_recurring
step plugins_ir bundle exec rake redmine:plugins:migrate || exit 1
psql -d r70h_upg -Atc "select count(*) from schema_migrations"
PGPASSWORD=redmine pg_dump -h 127.0.0.1 -U redmine -Fc r70h_upg > "$S/r70h_upg-51-empty.dump"
