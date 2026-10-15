#!/bin/bash
# Smoke per plugin against the production server on :3000 (all plugins installed): every GET page
# the plugin adds (its routes.rb) plus core pages, as admin; fails on HTTP 5xx, JS errors, missing
# assets. Uses redmine_view_issue_description's .codex/e2e kit for every plugin (identical in 41 of 43).
# One line per plugin in smoke.tsv; screenshots and smoke.md per plugin in e2e/<id>/.
set -uo pipefail
H=${H:-/home/user/r70h}; R=$H/redmine; KITE=$H/src/redmine_view_issue_description/.codex/e2e
for _ in $(seq 1 90); do [ "$(timeout 10 curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3000/login)" = 200 ] && break; sleep 2; done
touch "$H/smoke.tsv"; sed -i "/^DONE$/d" "$H/smoke.tsv"
export REDMINE_DIR=$R RMP_URL=http://127.0.0.1:3000 LANG=C.UTF-8 LC_ALL=C.UTF-8
for id in $(cut -f2 "$H/heads.tsv"); do
  grep -q "^$id	" "$H/smoke.tsv" && continue
  [ "$(timeout 10 curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3000/login)" = 200 ] || { echo "server down before $id" >&2; exit 3; }
  out=$H/e2e/$id; mkdir -p "$out"; routes=$R/tmp/e2e-routes-$id.txt
  (cd "$R" && RAILS_ENV=production timeout 600 bundle exec rails runner "$KITE/routes.rb" "$id" > "$routes" 2> "$out/routes.err")
  n=$(wc -l < "$routes")
  (cd "$KITE/../.." && PLUGIN_NAME=$id RMP_ROUTES_FILE=$routes RMP_E2E_OUT=$out timeout 1200 node .codex/e2e/smoke.mjs > "$out/smoke.out" 2>&1); rc=$?
  pages=$(grep -c '^| ' "$out/smoke.md" 2>/dev/null); probs=$(grep -ciE 'HTTP 5|error|missing' "$out/smoke.out")
  [ "$(timeout 10 curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3000/login)" = 200 ] || { echo "server went down during $id, not recorded" >&2; exit 3; }
  printf '%s\t%s routes\texit=%s\tlines=%s\tproblem-lines=%s\n' "$id" "$n" "$rc" "$pages" "$probs" | tee -a "$H/smoke.tsv"
done
echo DONE >> "$H/smoke.tsv"
