#!/bin/bash
# Migration files per plugin on 5.1 (upg51) and 7.0 (redmine_b, or upg70 when present): version<TAB>file.
# Writes $S/mig51.tsv and $S/mig70.tsv (id, version, file, md5 of the file) and prints the per-plugin differences.
. "$(dirname "$0")/env.sh"
R70=${R70:-/home/user/r70h/redmine_b}; [ -d "$U70/plugins" ] && R70=$U70
for side in 51 70; do
  root=$U51; [ $side = 70 ] && root=$R70
  for d in "$root"/plugins/*/; do
    id=$(basename "$d")
    for f in "$d"db/migrate/*.rb; do
      [ -e "$f" ] || continue
      b=$(basename "$f"); v=$(echo "$b" | grep -oE '^[0-9]+')
      printf '%s\t%s\t%s\t%s\n' "$id" "$((10#$v))" "$b" "$(md5sum < "$f" | cut -c1-8)"
    done
  done | sort -k1,1 -k2,2n > "$S/mig$side.tsv"
done
echo "# plugin  version  5.1-file  7.0-file  (same content?)"
join -t $'\t' -a1 -a2 -e '-' -o 0,1.2,1.3,2.2,2.3 \
  <(awk -F'\t' '{print $1":"$2"\t"$3"\t"$4}' "$S/mig51.tsv" | sort -t $'\t' -k1,1) \
  <(awk -F'\t' '{print $1":"$2"\t"$3"\t"$4}' "$S/mig70.tsv" | sort -t $'\t' -k1,1) |
  awk -F'\t' '{ if ($2!=$4 || $3!=$5) { s = ($2=="-") ? "NEW-ON-7.0" : (($4=="-") ? "GONE-ON-7.0" : (($2!=$4) ? "SAME-NUMBER-OTHER-FILE" : "CONTENT-CHANGED")); print $1"\t"$2"\t"$4"\t"s } }' | sort -t: -k1,1 -k2,2n
