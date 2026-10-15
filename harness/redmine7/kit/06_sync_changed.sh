#!/bin/bash
# Brings every plugin in redmine_b to its current redmine70-migration head and runs the suites of the
# plugins that moved, in the full set. Usage: 06_sync_changed.sh <label> [extra suite ids]
# Plugins with new migrations are listed in logs/<label>-newmig.txt and NOT run: migrate the template first.
set -uo pipefail
H=/home/user/r70h; label=$1; extra=${2:-}
changed=""; : > "$H/logs/$label-newmig.txt"
while IFS=$'\t' read -r repo id old; do
  d=$H/src/$repo
  git -C "$d" fetch -q --depth 10 origin "+redmine70-migration:refs/remotes/origin/redmine70-migration" 2>/dev/null || continue
  new=$(git -C "$d" rev-parse --short origin/redmine70-migration)
  [ "$new" = "$old" ] && continue
  oldm=$(ls "$d/db/migrate" 2>/dev/null | sort)
  git -C "$d" checkout -q -B redmine70-migration origin/redmine70-migration
  rm -rf "$H/redmine_b/plugins/$id"; mkdir "$H/redmine_b/plugins/$id"
  tar -C "$d" --exclude=.git -cf - . | tar -C "$H/redmine_b/plugins/$id" -xf -
  sed -i "s/^$repo\t.*/$repo\t$id\t$new/" "$H/heads-latest.tsv"
  if [ "$oldm" != "$(ls "$d/db/migrate" 2>/dev/null | sort)" ]; then echo "$id" >> "$H/logs/$label-newmig.txt"; else changed="$changed $id"; fi
  echo "$repo $old -> $new"
done < "$H/heads-latest.tsv"
ids=$(echo "$changed $extra" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ')
echo "run: $ids"; echo "new migrations: $(tr '\n' ' ' < "$H/logs/$label-newmig.txt")"
[ -n "$ids" ] && "$H/kit/05_attrib.sh" "$label" "" "$ids" > "$H/logs/05_$label.out" 2>&1
cat "$H/attrib-$label.tsv" 2>/dev/null
