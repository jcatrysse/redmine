#!/bin/bash
# Smoke crawl as admin: 70 = the upgraded 7.0 on :3200 (r70h_upg70), 51 = the 5.1 original on :3201 (r70h_upg),
# to tell an upgrade problem from one production already has. Seeds + every GET link found.
# Writes $S/crawl<v>.tsv and $S/crawl<v>-500.txt (each 500 with the exception from the production log).
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd); . "$D/env.sh"
v=${1:-70}; who=${2:-admin}   # second argument: bob = a project manager (Manager role, not admin)
sfx=$v; pw=Upgrade-Admin-2026; [ "$who" != admin ] && { sfx=$v-$who; pw=Upgrade-Rehearsal-2026; }
if [ "$v" = 70 ]; then root=$U70; port=3200; db=r70h_upg70; "$D/50_server70.sh" || exit 1
else root=$U51; port=3201; db=r70h_upg; "$D/23_server51.sh" || exit 1; fi
logf=$root/log/production.log; start=$(wc -l < "$logf" 2>/dev/null || echo 0)
ids() { psql -d $db -Atc "$1" | tr '\n' ' '; }
{
  echo / /projects /issues /my/page /my/account /admin /admin/plugins /admin/info /settings /roles /trackers /issue_statuses /custom_fields /users /groups /workflows /auth_sources /enumerations /activity /time_entries /search?q=seed
  for p in geo-main geo-sub1 geo-sub2 helpdesk crm; do echo /projects/$p /projects/$p/issues /projects/$p/settings /projects/$p/activity /projects/$p/roadmap /projects/$p/wiki /projects/$p/issues/new /projects/$p/agile/board /projects/$p/agile/charts /projects/$p/contacts /projects/$p/deals; done
  for i in $(ids "select id from issues order by id"); do echo /issues/$i; done
  for i in $(ids "select id from issues order by id limit 3"); do echo /issues/$i/edit; done
  for q in $(ids "select q.id||':'||coalesce(p.identifier,'') from queries q left join projects p on p.id=q.project_id where q.type='IssueQuery'"); do p=${q#*:}; [ -n "$p" ] && echo "/projects/$p/issues?query_id=${q%%:*}" || echo "/issues?query_id=${q%%:*}"; done
  for f in $(ids "select id from custom_fields where field_format='sql_search'"); do echo "/custom_sql_search/search?custom_field_id=$f&q=Cont&project_id=1&issue_id=1"; done
  echo /projects/geo-main/issues/report /projects/geo-main/digest_rules /projects/geo-main/subtask_settings/show /webhooks
  for q in $(ids "select id||':'||coalesce(project_id::text,'') from queries where type='AgileQuery'"); do p=${q#*:}; [ -n "$p" ] && echo "/projects/$(psql -d $db -Atc "select identifier from projects where id=$p")/agile/board?query_id=${q%%:*}" || echo "/agile/board?query_id=${q%%:*}"; done
  for c in $(ids "select id from contacts"); do echo /contacts/$c; done
  for c in $(ids "select id from deals"); do echo /deals/$c; done
  echo /contacts /deals /people /departments /custom_workflows /view_customizes /helpdesk_mail_rules /webhooks /project_workflows /checklist_templates /settings/plugin/redmine_ldap_sync /ldap_settings
  for t in $(ids "select name from settings where name like 'plugin_%'"); do echo /settings/plugin/${t#plugin_}; done
  for p in geo-main helpdesk; do for t in info modules members issues versions categories wiki repositories activities; do echo "/projects/$p/settings/$t"; done; done
} | tr ' ' '\n' | grep -v '^$' > "$S/smoke-seeds$v.txt"
python3 -I "$S/py/crawl.py" http://127.0.0.1:$port $who $pw "$S/crawl$sfx.tsv" ${MAX:-900} < "$S/smoke-seeds$v.txt" | tee "$LOGS/51_crawl$sfx.out"
# 500s with the exception from the log
tail -n +$((start + 1)) "$logf" > "$S/crawl$sfx-production.log"
python3 -I - "$S/crawl$sfx-production.log" > "$S/crawl$sfx-500.txt" <<'PY'
import re, sys
reqs, cur = [], None
for line in open(sys.argv[1], errors='replace'):
    m = re.search(r'\] Started (GET|POST) "([^"]+)"', line) or re.search(r'Started (GET|POST) "([^"]+)"', line)
    if m: cur = {'url': m.group(2), 'lines': []}; reqs.append(cur); continue
    if cur is not None: cur['lines'].append(line.rstrip())
for r in reqs:
    if any(re.search(r'Completed 500', l) for l in r['lines']):
        ex = [l for l in r['lines'] if re.search(r'Error|Exception|undefined|uninitialized|NoMethod|ActionView::Template::Error|PG::', l)]
        app = [l for l in r['lines'] if re.search(r'plugins/|app/(views|models|helpers|controllers)/', l) and 'vendor/bundle' not in l]
        print('== 500', r['url']); [print('   ', l[-400:]) for l in ex[:4]]; [print('   ', l[-300:]) for l in app[:4]]
PY
grep -c '^== 500' "$S/crawl$sfx-500.txt"
