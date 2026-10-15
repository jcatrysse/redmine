#!/bin/bash
# Fresh PostgreSQL databases, core and plugin migrations (dev and test), default data (en),
# secret token. Default data is loaded with redmine_issue_field_visibility moved aside when
# its alias_method patch still recurses with redmine_agile (finding 16): the seed is core data.
set -uo pipefail
H=${H:-/home/user/r70h}; R=$H/redmine; L=$H/logs; cd "$R"
export RAILS_ENV=development
step() { local name=$1; shift; echo "== $name"; "$@" > "$L/db-$name.log" 2>&1; local rc=$?; echo "   exit=$rc"; [ $rc -ne 0 ] && tail -5 "$L/db-$name.log"; return 0; }
step drop bash -c 'bundle exec rake db:drop RAILS_ENV=development; bundle exec rake db:drop RAILS_ENV=test'
step secret bundle exec rake generate_secret_token
step create bash -c 'bundle exec rake db:create RAILS_ENV=development && bundle exec rake db:create RAILS_ENV=test'
step migrate_dev bundle exec rake db:migrate
step plugins_dev bundle exec rake redmine:plugins:migrate
step migrate_test bundle exec rake db:migrate RAILS_ENV=test
step plugins_test bundle exec rake redmine:plugins:migrate RAILS_ENV=test
echo "== default data (all plugins)"
REDMINE_LANG=en bundle exec rake redmine:load_default_data > "$L/db-default.log" 2>&1; rc=$?; echo "   exit=$rc"
if [ $rc -ne 0 ]; then
  tail -3 "$L/db-default.log"
  echo "== default data with redmine_issue_field_visibility aside (finding 16)"
  mv plugins/redmine_issue_field_visibility "$H/ifv.aside"
  REDMINE_LANG=en bundle exec rake redmine:load_default_data > "$L/db-default-aside.log" 2>&1; echo "   exit=$?"
  mv "$H/ifv.aside" plugins/redmine_issue_field_visibility
fi
