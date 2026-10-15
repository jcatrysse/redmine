#!/bin/bash
# Redmine 5.1-stable-GEOxyz plus the production plugin set (plugins-5.1.tsv), directory = plugin id.
# redmine_custom_workflows: production runs 0398974 (2.1.3 devel), not the 5.x branch.
# Writes $S/heads51.tsv (repo, ref, id, sha).
set -uo pipefail
. "$(dirname "$0")/env.sh"
if [ ! -d "$U51/.git" ]; then
  rm -rf "$U51"; git clone -q --depth 1 -b 5.1-stable-GEOxyz https://github.com/jcatrysse/redmine.git "$U51"
fi
echo "redmine51 $(git -C "$U51" log -1 --format='%h %cd %s' --date=short)"
: > "$S/heads51.tsv"
mkdir -p "$U51/.psrc"
while IFS=$'\t' read -r repo branch; do
  [ -z "$repo" ] && continue
  d="$U51/.psrc/$repo"
  if [ ! -d "$d/.git" ]; then
    if [ "$repo" = redmine_custom_workflows ]; then
      git init -q "$d" && git -C "$d" remote add origin "https://github.com/jcatrysse/$repo.git" &&
      git -C "$d" fetch -q --depth 1 origin 03989743d72289afa84d62747a447b13a062fd2d && git -C "$d" checkout -q FETCH_HEAD
      branch=0398974
    else
      git clone -q --depth 1 -b "$branch" "https://github.com/jcatrysse/$repo.git" "$d" || { echo "CLONE FAILED $repo $branch"; continue; }
    fi
  fi
  [ "$repo" = redmine_custom_workflows ] && branch=0398974
  id=$(grep -hoE "Redmine::Plugin\.register[ (]+:?['\"]?[A-Za-z0-9_]+" "$d/init.rb" | head -1 | sed -E "s/.*register[ (]+:?['\"]?//")
  printf '%s\t%s\t%s\t%s\n' "$repo" "$branch" "$id" "$(git -C "$d" rev-parse --short HEAD)" >> "$S/heads51.tsv"
  rm -rf "$U51/plugins/$id"; mkdir -p "$U51/plugins/$id"
  tar -C "$d" --exclude=.git -cf - . | tar -C "$U51/plugins/$id" -xf -
done < "$S/plugins-5.1.tsv"
cat "$S/heads51.tsv"
