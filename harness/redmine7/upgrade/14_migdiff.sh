#!/bin/bash
# Semantic differences between same-numbered plugin migrations on 5.1 and 7.0 (ignores the Migration[x.y]
# superclass, comment lines and trailing blanks).
. "$(dirname "$0")/env.sh"
R70=${R70:-/home/user/r70h/redmine_b}; [ -d "$U70/plugins" ] && R70=$U70
norm() { sed -E 's/Migration(\[[0-9.]+\])?/Migration/; s/[[:space:]]+$//; /^[[:space:]]*#/d' "$1" | grep -v '^$'; }
grep -E 'CONTENT-CHANGED|SAME-NUMBER' "$LOGS/13_miglists.out" | while IFS=$'\t' read k a b s; do
  id=${k%%:*}
  d=$(diff <(norm "$U51/plugins/$id/db/migrate/$a") <(norm "$R70/plugins/$id/db/migrate/$b"))
  [ -n "$d" ] && { echo "=== $id 5.1:$a 7.0:$b"; echo "$d"; }
done
