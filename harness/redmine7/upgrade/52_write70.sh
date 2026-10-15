#!/bin/bash
# Write smoke on the upgraded 7.0 (52_write70.rb) plus the cron tasks production runs.
. "$(dirname "$0")/env.sh"
cd "$U70"
bundle exec rails runner "$S/52_write70.rb" 2>&1 | grep -v warning | tee "$LOGS/52_write70.log" | sed -n '/WRITE SUMMARY/,$p'
for t in redmine:issue_recurring:renew_all redmine:issue_digest:send; do
  echo "== rake $t"; timeout 300 bundle exec rake $t > "$LOGS/52_$(echo $t | tr ':' '_').log" 2>&1; echo "   exit=$?"; grep -v -E '^/|^\s+/|warning' "$LOGS/52_$(echo $t | tr ':' '_').log" | head -6 | sed 's/^/   | /'
done
psql -d r70h_upg70 -Atc "select 'issues '||count(*) from issues"
ls "$U70/tmp/mails" 2>/dev/null | wc -l
