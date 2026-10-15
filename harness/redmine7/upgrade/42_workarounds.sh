#!/bin/bash
# Workarounds that let the rehearsal go on past a failing step, so later problems show too. They are the
# rehearsal's, not a recommended production procedure (the fix suggestions are in the report).
#   before_core_retry : W1, the 5.1-GEOxyz webhook tables block core 20251007073256: move them aside
#   after_migrate     : W1, copy the 5.1 webhooks into the 7.0 tables, drop the aside copy
#   before_plugins_retry : placeholder for plugin migration failures
set -uo pipefail
. "$(dirname "$0")/env.sh"
case "$1" in
before_core_retry)
  psql -v ON_ERROR_STOP=1 -d r70h_upg70 <<'SQL'
CREATE SCHEMA geo51;
ALTER TABLE webhooks SET SCHEMA geo51;
ALTER TABLE projects_webhooks SET SCHEMA geo51;
ALTER TABLE trackers_webhooks SET SCHEMA geo51;
DELETE FROM schema_migrations WHERE version IN ('20231120120000','20231120120100','20231120120200');
SQL
  echo "W1: 5.1 webhook tables moved to schema geo51" ;;
after_migrate)
  psql -v ON_ERROR_STOP=1 -d r70h_upg70 <<'SQL'
DO $$ BEGIN
IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'geo51') THEN
  INSERT INTO public.webhooks (id, url, secret, events, user_id, active, created_at, updated_at)
    SELECT id, url, secret, events, user_id, active, created_at, updated_at FROM geo51.webhooks;
  INSERT INTO public.projects_webhooks (project_id, webhook_id) SELECT project_id, webhook_id FROM geo51.projects_webhooks;
  INSERT INTO public.trackers_webhooks (tracker_id, webhook_id) SELECT tracker_id, webhook_id FROM geo51.trackers_webhooks;
  PERFORM setval('public.webhooks_id_seq', greatest((SELECT max(id) FROM public.webhooks), 1));
  DROP SCHEMA geo51 CASCADE;
  RAISE NOTICE 'W1: webhooks copied into the 7.0 tables';
END IF;
END $$;
SQL
  ;;
data_fixes)
  # W2: redmine_mail_digest rules stored as YAML on 5.1 (Rails 6.1 ignores serialize ..., coder: JSON) -> JSON
  # W3: tags.color / taggings.color, which redmineup >= 1.1.5 creates on a fresh install and reads
  cd "$U70" && bundle exec rails runner '
    c = ActiveRecord::Base.connection
    n = 0
    c.select_all("SELECT id, schedule_config, recipient_modes FROM issue_digest_rules").each do |r|
      sets = %w[schedule_config recipient_modes].select { |k| r[k].to_s.start_with?("---") }.map do |k|
        "#{k} = #{c.quote(JSON.generate(YAML.safe_load(r[k], permitted_classes: [Symbol])))}"
      end
      next if sets.empty?
      c.execute("UPDATE issue_digest_rules SET #{sets.join(", ")} WHERE id = #{r["id"].to_i}"); n += 1
    end
    puts "W2: #{n} digest rule(s) converted from YAML to JSON"
    ActiveRecord::Base.add_tags_column(:tags, name: :color, type: :integer, default: nil)
    ActiveRecord::Base.add_tags_column(:taggings, name: :color, type: :integer, default: nil)
    puts "W3: tags.color #{c.column_exists?(:tags, :color)}, taggings.color #{c.column_exists?(:taggings, :color)}"
  ' 2>&1 | grep -v warning ;;
before_plugins_retry)
  echo "no plugin workaround defined"; exit 1 ;;
esac
