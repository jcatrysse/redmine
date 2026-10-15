#!/bin/bash
# Restore the freshly migrated 5.1 database (12_db51.sh dump) and seed it (20_seed51.rb), then the plugin
# settings through the UI (22_settings51.py, needs the 5.1 server: 23_server51.sh).
set -uo pipefail
. "$(dirname "$0")/env.sh"
export PATH=/opt/rbenv/versions/3.2.6/bin:$PATH
cd "$U51"
dropdb --if-exists r70h_upg && createdb -O redmine -E UTF8 -T template0 r70h_upg && pg_restore -d r70h_upg "$S/r70h_upg-51-empty.dump" || exit 1
rm -rf "$U51/files/"[0-9]*
bundle exec rails runner "$S/20_seed51.rb" 2>&1 | grep -v -E 'warning: |DEPRECATION' | tee "$LOGS/21_seed51.log"
