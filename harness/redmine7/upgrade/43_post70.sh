#!/bin/bash
# The upgrade steps the plugins' docs/REDMINE7-MIGRATION.md list ("After the upgrade (production)" and
# "Data-upgrade en acties na migratie"), on the upgraded copy. Each step logs to $LOGS/43_<n>.log.
# The theme changer conversion is 45_theme70.sh (it installs another plugin).
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd); . "$D/env.sh"
cd "$U70"
step() { local name=$1; shift; echo "== $name"; "$@" > "$LOGS/43_$name.log" 2>&1; local rc=$?; echo "   exit=$rc"; grep -v -E '^/|^\s+/|warning:|^\s*$' "$LOGS/43_$name.log" | head -${LINES_SHOWN:-8} | sed 's/^/   | /'; return 0; }
run() { bundle exec rails runner "$@"; }
# run 1 needed W1 here; since core 8dc5e73 the migrations restore the 5.1 webhooks themselves
[ "${WORKAROUNDS:-0}" = 1 ] && "$D/42_workarounds.sh" after_migrate
# redmine_contacts_helpdesk: saved queries with customer/customer_company filters and columns
step helpdesk_fix_renamed_queries bundle exec rake redmine:plugins:helpdesk:fix_renamed_queries
# redmine_checklists: since 6e4403b migration 008 converts subject to text (no manual ALTER any more): check only
step checklists_subject_type psql -d r70h_upg70 -Atc "select data_type, character_maximum_length from information_schema.columns where table_name='checklists' and column_name='subject'"
# redmineup_tags: migration 005 rebuilds the cache now (manual rebuild no longer needed): check it against the tags
step tags_cache_check run 'bad = Issue.all.reject { |i| i.cached_tag_names.to_s == i.tags.map(&:name).uniq.sort.join(",") }; puts "issues with tags: #{Issue.where.not(cached_tag_names: [nil, ""]).count}, cache differs from tags: #{bad.map(&:id).inspect}"; puts "tags.color #{ActiveRecord::Base.connection.column_exists?(:tags, :color)}, taggings.color #{ActiveRecord::Base.connection.column_exists?(:taggings, :color)}"'
# redmine_issue_view_columns: 003 ran on 7.0; check the core setting it fills
step issue_view_columns_core_setting run 'p Setting.related_issues_default_columns'
# redmine_project_workflows: backup, optional deduplicate, roles
step project_workflows_backup bundle exec rake redmine_project_workflows:backup FILE=$S/pw-backup.json FORCE=1
step project_workflows_dedup bundle exec rake redmine_project_workflows:deduplicate_workflow_rules
step project_workflows_roles run 'Role.sorted.each { |r| puts [r.name, (r.permissions.map(&:to_s).grep(/project_workflow/)).inspect].join(" ") }'
# redmine_more_previews: hand formats back to core
step more_previews_dry env DRY_RUN=1 bundle exec rake redmine_more_previews:use_core_previews
step more_previews_run bundle exec rake redmine_more_previews:use_core_previews
step more_previews_again bundle exec rake redmine_more_previews:use_core_previews
# computed_custom_field: formulas on Redmine 7
step computed_check_formulas bundle exec rake redmine:computed_custom_field:check_formulas
# redmine_custom_workflows: audit of stored scripts
step custom_workflows_audit bundle exec rake redmine:custom_workflows:audit
# view_customize: snippet audit
step view_customize_audit run plugins/view_customize/docs/audit_snippets.rb
# custom_field_sql: export the stored SQL fields
step custom_field_sql_export psql -d r70h_upg70 -c "SELECT id, name, field_format, format_store FROM custom_fields WHERE field_format IN ('sql','sql_search')"
# redmine_agile: optional clean-up of agile_sprint_id = 0
step agile_sprint_zero psql -d r70h_upg70 -c "UPDATE agile_data SET agile_sprint_id = NULL WHERE agile_sprint_id = 0"
step agile_public_boards psql -d r70h_upg70 -c "SELECT id, name, user_id FROM queries WHERE type IN ('AgileQuery','AgileChartsQuery') AND project_id IS NULL AND visibility <> 0"
step agile_global_sprints psql -d r70h_upg70 -c "SELECT id, project_id, name FROM agile_sprints WHERE sharing = 4"
# redmine_wiki_extensions: menus outside 1..5
step wiki_ext_menus psql -d r70h_upg70 -c "DELETE FROM wiki_extensions_menus WHERE menu_no NOT BETWEEN 1 AND 5"
# redmine_mail_digest: the documented check after 012, then the rule list
step mail_digest_valid run 'IssueDigestRule.find_each { |r| puts [r.id, r.valid?].inspect }'
step mail_digest_rules run 'IssueDigestRule.order(:project_id, :name).each { |r| puts [r.id, r.project.identifier, r.name, r.schedule_type, r.schedule_config, r.timezone].inspect }'
# redmine_subtask: candidates for the global/project template mix-up
step subtask_candidates psql -d r70h_upg70 -c "SELECT * FROM subtasks WHERE global = true AND template IN (SELECT id FROM issue_templates)"
# redmine_contacts_helpdesk: mail rule inventory
step helpdesk_mail_rules psql -d r70h_upg70 -c "SELECT id, mail_type, position, conditions, actions FROM helpdesk_mail_rules ORDER BY position"
# redmine_view_issue_description: roles, to compare with 5.1
step vid_roles run 'Role.sorted.each { |r| next unless r.has_permission?(:view_issues); t = r.permissions_all_trackers?(:view_issue_description) ? "all" : r.permissions_tracker_ids(:view_issue_description).join(","); puts [r.name, r.has_permission?(:view_issue_description) ? "view_issue_description: #{t}" : "NO view_issue_description", r.has_permission?(:view_watched_issues) ? "view_watched_issues" : "-"].join(" | ") }'
# redmine_itil_priority: who got override_itil_priority (migration 004)
step itil_override_roles run 'Role.sorted.each { |r| puts "#{r.name}: #{r.has_permission?(:override_itil_priority)}" }'
# bless_this_redmine_sso, ai_triage, reporter_dashboards: status tasks
step sso_status bundle exec rake redmine:bless_this_sso:status
step ai_triage_health bundle exec rake redmine_ai_triage:health
# redmine_ldap_sync: dry run (no LDAP server here: shows how it fails)
step ldap_dry_run timeout 120 env DRY_RUN=1 bundle exec rake redmine:plugins:ldap_sync:sync_all
echo "post steps done"
