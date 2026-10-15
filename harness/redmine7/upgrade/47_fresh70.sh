#!/bin/bash
# A fresh 7.0 install with the plugins of upg70 (database r70h_upg_fresh), for a schema to compare the upgrade
# with when upg70 carries other plugin heads than the kit's schema.rb. issue_recurring aside for the first
# plugin pass, as tools/testenv/setup.sh does (its rake file loads models).
set -uo pipefail
. "$(dirname "$0")/env.sh"
cd "$U70"
cp config/database.yml "$S/database.yml.upg70"
sed -i 's/database: r70h_upg70/database: r70h_upg_fresh/' config/database.yml
trap 'cp "$S/database.yml.upg70" "$U70/config/database.yml"; [ -d "$U70/.aside/issue_recurring" ] && mv "$U70/.aside/issue_recurring" "$U70/plugins/issue_recurring"' EXIT
dropdb --if-exists r70h_upg_fresh && createdb -O redmine -E UTF8 -T template0 r70h_upg_fresh || exit 1
mkdir -p "$U70/.aside"; mv plugins/issue_recurring "$U70/.aside/issue_recurring"
# Rails 8 db:migrate loads db/schema.rb into an empty database instead of migrating; the copied tree carries
# redmine_b's schema.rb (with plugin tables), which would leave plugin columns without their versions
rm -f db/schema.rb
bundle exec rake db:migrate > "$LOGS/47_fresh_migrate.log" 2>&1 || { echo "fresh db:migrate failed"; tail "$LOGS/47_fresh_migrate.log"; exit 1; }
bundle exec rake redmine:plugins:migrate > "$LOGS/47_fresh_plugins.log" 2>&1 || { echo "fresh plugins:migrate failed"; tail "$LOGS/47_fresh_plugins.log"; exit 1; }
mv "$U70/.aside/issue_recurring" plugins/issue_recurring
bundle exec rake redmine:plugins:migrate >> "$LOGS/47_fresh_plugins.log" 2>&1 || { echo "fresh plugins:migrate (2) failed"; exit 1; }
SCHEMA=$S/schema70-fresh.rb bundle exec rake db:schema:dump > "$LOGS/47_fresh_dump.log" 2>&1 && echo "fresh schema: $S/schema70-fresh.rb"
python3 -I "$S/py/schema_diff.py" "$S/schema70-fresh.rb" /home/user/r70h/kit/schema.rb fresh-here kit
