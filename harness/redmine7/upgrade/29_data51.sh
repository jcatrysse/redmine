#!/bin/bash
# Full 5.1 data state: seed (models), plugin settings (UI), counts, fingerprints, dump. Re-runnable.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd); . "$D/env.sh"
"$D/23_server51.sh" stop
"$D/21_seed51.sh" | sed -n '/SEED SUMMARY/,$p'
"$D/23_server51.sh" && "$D/22_settings51.sh" | grep -v -E 'POST 302'
# run 2 additions: a digest rule saved through the 5.1 form (F2), non-default renamed settings (F6)
python3 -I "$D/py/form_rule51.py" http://127.0.0.1:3201 Upgrade-Admin-2026
(cd "$U51" && PATH=/opt/rbenv/versions/3.2.6/bin:$PATH bundle exec rails runner "$D/24_seed51_extra.rb" 2>&1 | grep -v warning)
