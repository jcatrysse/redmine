#!/bin/bash
# Run 2 (2026-10-15): the current state (redmine_b 8369308 + current heads, helpdesk 2dae28e), no workarounds.
# Before this: 29_data51.sh (with the run 2 additions), 33_before51.sh, HELPDESK_REF=2dae28e 40_copy70.sh.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
"$D/13_miglists.sh" > "$D/logs/13_miglists.out"; "$D/14_migdiff.sh" > "$D/logs/14_migdiff.out"
echo "== fresh install"; "$D/47_fresh70.sh"
echo "== upgrade (no workarounds)"; "$D/41_upgrade70.sh" || { echo "UPGRADE FAILED"; exit 1; }
REF=$D/schema70-fresh.rb "$D/44_schema.sh" after-migrate
"$D/43_post70.sh" > "$D/logs/43_post70.out" 2>&1; echo "== post steps"; grep -E '^== |exit=[1-9]' "$D/logs/43_post70.out" | paste -sd' ' | fold -w 300
REF=$D/schema70-fresh.rb "$D/44_schema.sh" after-post-steps
"$D/46_after70.sh" > "$D/logs/46_after70.out" 2>&1; grep -E 'different=|DIFFERENT' "$D/logs/46_after70.out"
echo "== crawl 7.0 admin"; "$D/51_smoke.sh" 70 | tail -3
echo "== crawl 7.0 bob"; "$D/51_smoke.sh" 70 bob | tail -3
echo "== write"; "$D/52_write70.sh" | grep -v '^OK '
echo "== theme"; "$D/45_theme70.sh" | grep -E 'exit=[1-9]|theme assets'
echo "== crawl 5.1 admin"; "$D/51_smoke.sh" 51 | tail -3
echo "== crawl 5.1 bob"; "$D/51_smoke.sh" 51 bob | tail -3
"$D/50_server70.sh" stop; "$D/23_server51.sh" stop
echo "== extras"; "$D/56_extras.sh"
echo "RUN2 DONE"
