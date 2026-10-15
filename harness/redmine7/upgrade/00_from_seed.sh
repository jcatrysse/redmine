#!/bin/bash
# 00_all.sh from the seed on (the 5.1 tree and bundle already in place)
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
"$D/29_data51.sh"                # seed through the plugins' models (20_seed51.rb), settings through the UI (22)
"$D/33_before51.sh"              # counts, snapshot, workflow fingerprint, roles; dump r70h_upg-51-seeded.dump
"$D/50_server70.sh" stop
"$D/40_copy70.sh"                # redmine_b -> upg70 (waits for .coordinator-ready), heads70.tsv
"$D/13_miglists.sh" > "$D/logs/13_miglists.out"; "$D/14_migdiff.sh" > "$D/logs/14_migdiff.out"
REF=/home/user/r70h/kit/schema.rb
if [ -n "${HELPDESK_REF:-}" ]; then "$D/47_fresh70.sh"; REF=$D/schema70-fresh.rb; fi   # fresh install for the schema
WORKAROUNDS=1 "$D/41_upgrade70.sh"   # createdb -T, db:migrate (fails: webhooks; W1), plugins:migrate
REF=$REF "$D/44_schema.sh" after-migrate
"$D/43_post70.sh" > "$D/logs/43_post70.out" 2>&1      # documented post-upgrade steps
REF=$REF "$D/44_schema.sh" after-post-steps
"$D/46_after70.sh" > "$D/logs/46_after70.out" 2>&1     # counts, snapshot, fingerprint vs 5.1
"$D/51_smoke.sh" 70; cp "$D/crawl70.tsv" "$D/crawl70-asis.tsv"; cp "$D/crawl70-500.txt" "$D/crawl70-500-asis.txt"
"$D/42_workarounds.sh" data_fixes   # W2 digest YAML->JSON, W3 tags.color: what hides behind those 500s
"$D/51_smoke.sh" 70
"$D/52_write70.sh"               # write smoke + cron tasks on the upgraded data
"$D/45_theme70.sh"               # redmine_user_specific_theme -> redmine_theme_changer conversion
"$D/51_smoke.sh" 51              # the 5.1 original, to tell old problems from new ones
"$D/50_server70.sh" stop; "$D/23_server51.sh" stop
"$D/56_extras.sh"                # orphans, helpdesk head switch, reply routing (changes data)
"$D/90_cleanup.sh"               # drop the r70h_upg* databases
