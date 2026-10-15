#!/bin/bash
# Path of an environment that already ran the previous helpdesk head (ff0387a: 013 = GEOxyz reopen_locked) and then
# gets the 4.4.0 head (5478149: 013 = vendor rename, 014 indexes, 015 = GEOxyz): upgrade a copy of the seeded 5.1
# database (r70h_upg70b) with ff0387a, then switch the plugin to 5478149 and migrate again.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd); . "$D/env.sh"
cd "$U70"
"$D/50_server70.sh" stop
cp config/database.yml "$S/database.yml.upg70"
mkdir -p "$U70/.aside"; cp -a plugins/redmine_contacts_helpdesk "$U70/.aside/hd-current"
restore() { cp "$S/database.yml.upg70" "$U70/config/database.yml"; rm -rf "$U70/plugins/redmine_contacts_helpdesk"; mv "$U70/.aside/hd-current" "$U70/plugins/redmine_contacts_helpdesk"; }
trap restore EXIT
sed -i 's/database: r70h_upg70$/database: r70h_upg70b/' config/database.yml
dropdb --if-exists r70h_upg70b && createdb -O redmine -T r70h_upg r70h_upg70b || exit 1
psql -d r70h_upg70b -qc "CREATE SCHEMA geo51; ALTER TABLE webhooks SET SCHEMA geo51; ALTER TABLE projects_webhooks SET SCHEMA geo51; ALTER TABLE trackers_webhooks SET SCHEMA geo51; DELETE FROM schema_migrations WHERE version IN ('20231120120000','20231120120100','20231120120200')"
rm -rf plugins/redmine_contacts_helpdesk; mkdir plugins/redmine_contacts_helpdesk
tar -C /home/user/r70h/src/redmine_contacts_helpdesk --exclude=.git -cf - . | tar -C plugins/redmine_contacts_helpdesk -xf -
echo "helpdesk head 1: $(git -C /home/user/r70h/src/redmine_contacts_helpdesk log -1 --format='%h %s')"
bundle exec rake db:migrate > "$LOGS/48_core.log" 2>&1 || { echo core failed; exit 1; }
bundle exec rake redmine:plugins:migrate > "$LOGS/48_plugins_old.log" 2>&1 || { echo plugins failed; tail "$LOGS/48_plugins_old.log"; exit 1; }
q() { psql -d r70h_upg70b -Atc "select string_agg(version, ' ' order by version) from schema_migrations where version like '%-redmine_contacts_helpdesk'"; psql -d r70h_upg70b -Atc "select string_agg(column_name||':'||data_type, ' ' order by column_name) from information_schema.columns where table_name='helpdesk_tickets' and column_name in ('reopen_locked','last_customer_response_at','last_contact_response_at','to_address','cc_address')"; psql -d r70h_upg70b -Atc "select string_agg(indexname, ' ') from pg_indexes where indexname in ('index_journal_messages_on_message_date','index_helpdesk_tickets_on_ticket_date')"; }
echo "after ff0387a:"; q
rm -rf plugins/redmine_contacts_helpdesk; mkdir plugins/redmine_contacts_helpdesk
tar -C "$S/hd-src" --exclude=.git -cf - . | tar -C plugins/redmine_contacts_helpdesk -xf -
echo "helpdesk head 2: $(git -C "$S/hd-src" log -1 --format='%h %s')"
bundle exec rake redmine:plugins:migrate > "$LOGS/48_plugins_new.log" 2>&1 || { echo plugins new failed; tail "$LOGS/48_plugins_new.log"; exit 1; }
grep -E '^== [0-9]+ .*migrat(ing|ed)' "$LOGS/48_plugins_new.log" | grep migrated
echo "after 5478149:"; q
bundle exec rails runner 'p HelpdeskTicket.order(:id).first.attributes.slice("last_contact_response_at", "reopen_locked")' 2>&1 | grep -v warning
