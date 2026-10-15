#!/bin/bash
# Stop the rehearsal's servers and drop its databases (the trees upg51/upg70 and these scripts stay).
. "$(dirname "$0")/env.sh"
"$(dirname "$0")/50_server70.sh" stop; "$(dirname "$0")/23_server51.sh" stop
for db in $(psql -d postgres -Atc "select datname from pg_database where datname like 'r70h\_upg%'"); do dropdb "$db" && echo "dropped $db"; done
