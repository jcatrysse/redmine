#!/bin/bash
# Create r70h_perf_all from the migrated test template, migrate it to the current plugin heads, load default data.
set -e
source /tmp/claude-0/-home-user/e98afdbb-f85a-54ab-abad-04a5111765a8/scratchpad/perf44/env.sh
pg_lsclusters | grep -q online || bash /home/user/r70h/kit/resume.sh
if ! su postgres -c "psql -Atc \"select 1 from pg_database where datname='$DB'\"" | grep -q 1; then
  su postgres -c "createdb -O redmine -T r70h_test_tpl $DB"
fi
cd $RC
[ -f $P/database.yml.orig ] || cp $RC/config/database.yml $P/database.yml.orig
cp $P/database.yml $RC/config/database.yml
cp $RC/db/schema.rb $P/schema.rb.before-migrate 2>/dev/null || true
bundle exec rake db:migrate redmine:plugins:migrate 2>&1 | tail -5
cp $P/schema.rb.orig $RC/db/schema.rb
n=$(su postgres -c "psql -At $DB -c 'select count(*) from trackers'")
if [ "$n" = 0 ]; then REDMINE_LANG=en bundle exec rake redmine:load_default_data; fi
RAILS_ENV=production bundle exec rails runner $P/seed.rb
PGPASSWORD=redmine psql -h 127.0.0.1 -U redmine -q $DB -f $P/seed_fixup.sql
P=$P bundle exec rails runner $P/prep.rb
echo "setup done"
