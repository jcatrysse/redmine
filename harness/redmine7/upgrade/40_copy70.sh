#!/bin/bash
# Copy redmine_b (7.0-stable-GEOxyz with the 44 plugins on redmine70-migration) to upg70, without its logs,
# coverage, tmp and files; point production at r70h_upg70 (a copy of r70h_upg). redmine_b itself is not touched.
# Waits for the coordinator's ready flag. Records core and plugin heads in $S/heads70.tsv.
set -uo pipefail
. "$(dirname "$0")/env.sh"
B=/home/user/r70h/redmine_b
[ -e "$B/.coordinator-ready" ] || { echo "redmine_b not ready (no .coordinator-ready)"; exit 1; }
rm -rf "$U70"; mkdir -p "$U70"
tar -C "$B" --exclude=./log --exclude=./coverage --exclude=./tmp --exclude=./files --exclude=./.coordinator-ready -cf - . | tar -C "$U70" -xf -
mkdir -p "$U70/log" "$U70/tmp/pids" "$U70/files"
# the 5.1 attachments move with the database, as in production
cp -a "$U51/files/." "$U70/files/"
cat > "$U70/config/database.yml" <<YML
production:
  adapter: postgresql
  database: r70h_upg70
  host: 127.0.0.1
  username: redmine
  password: redmine
  encoding: utf8
YML
# mails of the copy go to its own tmp, never to /home/user/r70h/redmine
sed -i "s|/home/user/r70h/redmine/tmp/mails|$U70/tmp/mails|" "$U70/config/configuration.yml"; mkdir -p "$U70/tmp/mails"
# HELPDESK_REF=<branch or sha>: test another redmine_contacts_helpdesk head than redmine_b carries
if [ -n "${HELPDESK_REF:-}" ]; then
  h=$S/hd-src; rm -rf "$h"; git clone -q --depth 50 -b redmine70-migration https://github.com/jcatrysse/redmine_contacts_helpdesk.git "$h"
  git -C "$h" checkout -q "$HELPDESK_REF" || exit 1
  rm -rf "$U70/plugins/redmine_contacts_helpdesk"; mkdir -p "$U70/plugins/redmine_contacts_helpdesk"
  tar -C "$h" --exclude=.git -cf - . | tar -C "$U70/plugins/redmine_contacts_helpdesk" -xf -
  echo "redmine_contacts_helpdesk replaced by $(git -C "$h" log -1 --format='%h %s')"
fi
echo "core $(git -C "$U70" log -1 --format='%h %cd %s' --date=short)"
: > "$S/heads70.tsv"
while IFS=$'\t' read -r repo id sha; do
  src=/home/user/r70h/src/$repo; [ "$repo" = redmine_contacts_helpdesk ] && [ -n "${HELPDESK_REF:-}" ] && src=$S/hd-src
  d=$(diff -rq --exclude=.git "$src" "$U70/plugins/$id" 2>&1 | grep -v "^Only in $U70" | head -2 | tr '\n' ' ')
  printf '%s\t%s\t%s\t%s\n' "$repo" "$id" "$(git -C "$src" rev-parse --short HEAD)" "${d:-same-as-src}" >> "$S/heads70.tsv"
done < /home/user/r70h/heads-latest.tsv
grep -vc same-as-src "$S/heads70.tsv"
