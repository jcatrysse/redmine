#!/bin/bash
# Redmine 7.0-stable-GEOxyz plus every GEOxyz plugin on its redmine70-migration head.
# Plugin directory = plugin id from init.rb. Writes heads.tsv (repo, id, sha).
set -euo pipefail
H=${H:-/home/user/r70h}; KIT=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$H/src"
if [ ! -d "$H/redmine/.git" ]; then
  git clone -q --depth 1 -b 7.0-stable-GEOxyz https://github.com/jcatrysse/redmine.git "$H/redmine"
else
  git -C "$H/redmine" fetch -q --depth 1 origin "+7.0-stable-GEOxyz:refs/remotes/origin/7.0-stable-GEOxyz"
  git -C "$H/redmine" checkout -q -B 7.0-stable-GEOxyz origin/7.0-stable-GEOxyz
fi
echo "redmine $(git -C "$H/redmine" log -1 --format='%h %cd %s' --date=short)"
: > "$H/heads.tsv"
while read -r repo; do
  [ -z "$repo" ] && continue
  d="$H/src/$repo"
  if [ ! -d "$d/.git" ]; then git clone -q --depth 1 -b redmine70-migration "https://github.com/jcatrysse/$repo.git" "$d"
  else git -C "$d" fetch -q --depth 1 origin "+redmine70-migration:refs/remotes/origin/redmine70-migration"; git -C "$d" checkout -q -B redmine70-migration origin/redmine70-migration; fi
  id=$(grep -hoE "Redmine::Plugin\.register[ (]+:?['\"]?[A-Za-z0-9_]+" "$d/init.rb" | head -1 | sed -E "s/.*register[ (]+:?['\"]?//")
  printf '%s\t%s\t%s\n' "$repo" "$id" "$(git -C "$d" rev-parse --short HEAD)" >> "$H/heads.tsv"
  rm -rf "$H/redmine/plugins/$id"; mkdir -p "$H/redmine/plugins/$id"
  tar -C "$d" --exclude=.git -cf - . | tar -C "$H/redmine/plugins/$id" -xf -
done < "$KIT/plugins.txt"
cat "$H/heads.tsv"
