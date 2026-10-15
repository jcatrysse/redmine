#!/bin/bash
# Current remote redmine70-migration heads vs what redmine_b carries (heads-latest.tsv). Prints only differences.
. "$(dirname "$0")/env.sh"
while IFS=$'\t' read repo id sha; do
  r=$(git ls-remote https://github.com/jcatrysse/$repo.git refs/heads/redmine70-migration | cut -c1-7)
  [ "$r" != "$sha" ] && printf '%s\tredmine_b=%s\tremote=%s\n' "$repo" "$sha" "$r"
done < /home/user/r70h/heads-latest.tsv
echo "checked $(date -u +%FT%TZ)"
