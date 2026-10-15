#!/bin/bash
# Extra checks after the main run: schema_migrations orphans/skips, the helpdesk head switch path (with
# HELPDESK_REF), helpdesk reply routing on 5.1 vs 7.0 (changes data: last).
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd); . "$D/env.sh"
"$D/49_orphans.sh"
[ -n "${HELPDESK_REF:-}" ] && "$D/48_hd_switch.sh"
(cd "$U70" && bundle exec rails runner "$S/54_reply_scope.rb" 2>&1 | grep -v warning | sed 's/^/7.0: /')
(cd "$U51" && PATH=/opt/rbenv/versions/3.2.6/bin:$PATH bundle exec rails runner "$S/54_reply_scope.rb" 2>&1 | grep -v warning | sed 's/^/5.1: /')
