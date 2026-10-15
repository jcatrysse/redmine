#!/bin/bash
# Exact row count of every table in database $1, as "table<TAB>count", sorted. Usage: 30_counts.sh r70h_upg > file
. "$(dirname "$0")/env.sh"
db=$1
psql -d "$db" -Atc "select tablename from pg_tables where schemaname='public' order by 1" | while read -r t; do
  printf '%s\t%s\n' "$t" "$(psql -d "$db" -Atc "select count(*) from \"$t\"")"
done
