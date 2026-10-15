#!/bin/bash
# After a container restart: PostgreSQL, the e2e server (production, :3000), the test and smoke loops.
pg_ctlcluster 16 main start 2>/dev/null; sleep 2
if [ "$(timeout 10 curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3000/login)" != 200 ]; then
  rm -f /home/user/r70h/redmine/tmp/pids/e2e-3000.pid
  # Start puma directly: start_server.sh would run db:migrate and delete db/schema.rb, which the
  # test loop needs (maintain_test_schema!). The redmine_e2e database is already migrated and seeded.
  setsid nohup bash -c 'cd /home/user/r70h/redmine && exec bundle exec ruby bin/rails server -e production -b 127.0.0.1 -p 3000 -P tmp/pids/e2e-3000.pid' >> /home/user/r70h/redmine/log/e2e-server-3000.log 2>&1 < /dev/null &
fi
cd /tmp/claude-0/-home-user/e98afdbb-f85a-54ab-abad-04a5111765a8/scratchpad/r7/kit
pgrep -f "bash ./[0]3_tests.sh" >/dev/null || grep -q '^DONE' /home/user/r70h/tests.tsv || { setsid nohup bash ./03_tests.sh >> /home/user/r70h/logs/03_tests.out 2>&1 < /dev/null & }
pgrep -f "bash ./[0]4_smoke.sh" >/dev/null || grep -q '^DONE' /home/user/r70h/smoke.tsv || { setsid nohup bash ./04_smoke.sh >> /home/user/r70h/logs/04_smoke.out 2>&1 < /dev/null & }
echo "pg: $(pg_lsclusters | awk 'NR==2{print $4}')  tests: $(grep -vc DONE /home/user/r70h/tests.tsv)/44  smoke: $(grep -vc DONE /home/user/r70h/smoke.tsv)/44"
# an attribution run interrupted by a restart leaves plugins aside in redmine_b: put them back
for p in /home/user/r70h/aside-b/*; do [ -e "$p" ] && mv "$p" /home/user/r70h/redmine_b/plugins/; done 2>/dev/null; true
# the test LDAP that redmine_ldap_sync's suite needs (slapd 2.4 from the plugin's own kit, port 3389)
ldapsearch -x -H ldap://localhost:3389 -b dc=redmine,dc=org -s base dn >/dev/null 2>&1 || bash /home/user/r70h/src/redmine_ldap_sync/.codex/start_ldap.sh >/dev/null 2>&1; true
