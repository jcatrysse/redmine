#!/bin/bash
# schema_migrations rows of the upgraded database without a migration file in the 7.0 tree, and 7.0 migration
# files whose version was already recorded before the upgrade (= skipped), with the 5.1 file of that version.
. "$(dirname "$0")/env.sh"
db=${1:-r70h_upg70}
{
  for f in "$U70"/db/migrate/*.rb; do b=$(basename "$f"); v=${b%%_*}; echo "$((10#$v))"; done
  for d in "$U70"/plugins/*/; do id=$(basename "$d"); for f in "$d"db/migrate/*.rb; do [ -e "$f" ] || continue; b=$(basename "$f"); v=$(echo "$b" | grep -oE '^[0-9]+'); echo "$((10#$v))-$id"; done; done
} | sort -u > "$S/versions70-files.txt"
psql -d $db -Atc "select version from schema_migrations" | sort -u > "$S/versions70-db.txt"
echo "rows without a 7.0 file:"; comm -23 "$S/versions70-db.txt" "$S/versions70-files.txt" | sed 's/^/  /'
echo "7.0 files skipped because the version was recorded on 5.1 with another file:"
grep -E 'SAME-NUMBER' "$LOGS/13_miglists.out" | sed 's/^/  /'
echo "7.0 files skipped although the 5.1 file of the same version had other content (CONTENT-CHANGED, semantic part):"
grep '^===' "$LOGS/14_migdiff.out" | sed 's/^/  /'
echo "7.0 files never run:"; comm -13 "$S/versions70-db.txt" "$S/versions70-files.txt" | sed 's/^/  /'
