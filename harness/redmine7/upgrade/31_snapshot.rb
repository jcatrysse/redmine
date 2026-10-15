# Semantic snapshot of the seeded data, read with plain SQL so that the same script runs on 5.1 and on the
# upgraded 7.0 (models were renamed between them). OUT=file.json bundle exec rails runner 31_snapshot.rb
require 'json'
c = ActiveRecord::Base.connection
q = ->(sql) { c.select_all(sql).to_a }
cols = ->(t) { c.table_exists?(t) ? c.columns(t).map(&:name) : [] }
out = {}

out['issues'] = q.call(<<~SQL)
  SELECT i.id, i.project_id, i.tracker_id, i.subject, i.status_id, i.assigned_to_id, i.parent_id, i.fixed_version_id, i.priority_id,
         (SELECT count(*) FROM journals j WHERE j.journalized_type='Issue' AND j.journalized_id=i.id) AS journals,
         (SELECT count(*) FROM journal_details d JOIN journals j ON j.id=d.journal_id WHERE j.journalized_type='Issue' AND j.journalized_id=i.id) AS details,
         (SELECT string_agg(cf.name || '=' || coalesce(v.value,''), '|' ORDER BY cf.name, v.value) FROM custom_values v JOIN custom_fields cf ON cf.id=v.custom_field_id
            WHERE v.customized_type='Issue' AND v.customized_id=i.id) AS cf
  FROM issues i ORDER BY i.id
SQL
out['attachments'] = q.call('SELECT id, container_type, container_id, filename, disk_directory, disk_filename, filesize, digest FROM attachments ORDER BY id').map do |a|
  a.merge('on_disk' => File.exist?(File.join(Attachment.storage_path, a['disk_directory'].to_s, a['disk_filename'].to_s)))
end
out['relations'] = q.call('SELECT issue_from_id, issue_to_id, relation_type FROM issue_relations ORDER BY 1,2')
out['members'] = q.call("SELECT m.project_id, m.user_id, string_agg(r.name, ',' ORDER BY r.name) AS roles FROM members m JOIN member_roles mr ON mr.member_id=m.id JOIN roles r ON r.id=mr.role_id GROUP BY 1,2 ORDER BY 1,2")
out['webhooks'] = c.table_exists?(:webhooks) ? q.call('SELECT * FROM webhooks ORDER BY id').map { |w| w.except('created_at', 'updated_at') } : 'no table'
out['webhook_projects'] = c.table_exists?(:projects_webhooks) ? q.call('SELECT project_id, webhook_id FROM projects_webhooks ORDER BY 1,2') : 'no table'

# helpdesk
ht = cols.call('helpdesk_tickets')
out['helpdesk_tickets'] = q.call(<<~SQL)
  SELECT t.id, t.issue_id, i.project_id, t.contact_id, ct.email AS contact_email, t.from_address, t.to_address, t.cc_address, t.message_id,
         t.is_incoming, t.vote, #{ht.include?('reopen_locked') ? 't.reopen_locked' : 'NULL AS reopen_locked'}
  FROM helpdesk_tickets t LEFT JOIN issues i ON i.id=t.issue_id LEFT JOIN contacts ct ON ct.id=t.contact_id ORDER BY t.id
SQL
out['journal_messages'] = q.call(<<~SQL)
  SELECT m.id, m.journal_id, j.journalized_id AS issue_id, m.contact_id, m.is_incoming, m.from_address, m.to_address, m.cc_address, m.bcc_address, m.message_id
  FROM journal_messages m LEFT JOIN journals j ON j.id=m.journal_id ORDER BY m.id
SQL
out['helpdesk_mail_rules'] = q.call('SELECT id, mail_type, position, conditions, actions, user_id FROM helpdesk_mail_rules ORDER BY id')
out['canned_responses'] = q.call('SELECT id, name, project_id, is_public FROM canned_responses ORDER BY id')

# contacts / deals
out['contacts'] = q.call(<<~SQL)
  SELECT ct.id, ct.first_name, ct.last_name, ct.company, ct.email, ct.is_company, ct.visibility, ct.assigned_to_id,
         (SELECT string_agg(project_id::text, ',' ORDER BY project_id) FROM contacts_projects cp WHERE cp.contact_id=ct.id) AS projects,
         (SELECT string_agg(tg.name, ',' ORDER BY tg.name) FROM taggings tgg JOIN tags tg ON tg.id=tgg.tag_id WHERE tgg.taggable_type='Contact' AND tgg.taggable_id=ct.id) AS tags,
         (SELECT count(*) FROM addresses a WHERE a.addressable_type='Contact' AND a.addressable_id=ct.id) AS addresses
  FROM contacts ct ORDER BY ct.id
SQL
out['deals'] = q.call('SELECT d.id, d.name, d.project_id, d.status_id, d.contact_id, d.category_id, d.price, d.currency, (SELECT count(*) FROM deal_processes p WHERE p.deal_id=d.id) AS processes FROM deals d ORDER BY d.id')
out['notes'] = q.call('SELECT id, source_type, source_id, subject, type_id FROM notes ORDER BY id')
out['contacts_issues'] = q.call('SELECT * FROM contacts_issues ORDER BY 1,2')
out['deals_issues'] = q.call('SELECT issue_id, deal_id FROM deals_issues ORDER BY 1,2')

# agile
out['agile_sprints'] = q.call('SELECT id, project_id, name, status, start_date, end_date, sharing FROM agile_sprints ORDER BY id')
out['agile_data'] = q.call('SELECT issue_id, position, story_points, agile_sprint_id FROM agile_data ORDER BY issue_id')
out['agile_colors'] = q.call('SELECT container_type, container_id, color FROM agile_colors ORDER BY 1,2')

# checklists
out['checklists'] = q.call('SELECT id, issue_id, subject, is_done, position, is_section FROM checklists ORDER BY id')
out['checklist_templates'] = q.call('SELECT id, name, project_id, category_id, is_public, is_default, tracker_id, template_items FROM checklist_templates ORDER BY id')

# tags
out['issue_tags'] = q.call(<<~SQL)
  SELECT i.id, (SELECT string_agg(tg.name, ',' ORDER BY tg.name) FROM taggings tgg JOIN tags tg ON tg.id=tgg.tag_id WHERE tgg.taggable_type='Issue' AND tgg.taggable_id=i.id) AS tags,
         #{cols.call('issues').include?('cached_tag_names') ? 'i.cached_tag_names' : 'NULL'} AS cached
  FROM issues i ORDER BY i.id
SQL

# people
out['people_information'] = q.call('SELECT user_id, department_id, manager_id, job_title, workday_length FROM people_information ORDER BY user_id')
pa = cols.call('people_announcements')
out['people_announcements'] = q.call("SELECT id, description, #{pa.include?('department_id') ? 'department_id' : 'NULL AS department_id'}, " \
                                     "#{pa.include?('recipient_id') ? 'recipient_id, recipient_type' : 'NULL AS recipient_id, NULL AS recipient_type'} FROM people_announcements ORDER BY id")
out['departments'] = q.call('SELECT id, parent_id, name, head_id FROM departments ORDER BY id')
out['dayoffs'] = q.call('SELECT id, user_id, leave_type_id, approved FROM dayoffs ORDER BY id')

# custom workflows
out['custom_workflows'] = q.call("SELECT w.id, w.name, w.observable, w.active, w.is_for_all, (SELECT string_agg(project_id::text, ',' ORDER BY project_id) FROM custom_workflows_projects p WHERE p.custom_workflow_id=w.id) AS projects FROM custom_workflows w ORDER BY w.id")

# project workflows: the raw rows
out['workflow_rows_project'] = q.call("SELECT type, project_id, tracker_id, role_id, old_status_id, new_status_id, field_name, rule FROM workflows WHERE project_id IS NOT NULL ORDER BY 1,2,3,4,5,6,7")
out['workflow_rows_global'] = q.call('SELECT count(*) AS n FROM workflows WHERE project_id IS NULL')
out['role_permissions'] = q.call('SELECT id, name, permissions FROM roles ORDER BY id').map { |r| r.merge('permissions' => (YAML.safe_load(r['permissions'].to_s, permitted_classes: [Symbol]) || []).map(&:to_s).sort) }

# other plugins
out['issue_templates'] = q.call('SELECT id, title, project_id, tracker_id, enabled, is_default, checklist_json, builtin_fields_json FROM issue_templates ORDER BY id')
out['global_issue_templates'] = q.call('SELECT id, title, tracker_id, (SELECT string_agg(project_id::text, \',\' ORDER BY project_id) FROM global_issue_templates_projects p WHERE p.global_issue_template_id=g.id) AS projects FROM global_issue_templates g ORDER BY id')
out['note_templates'] = q.call('SELECT id, name, project_id, visibility FROM note_templates ORDER BY id')
out['issue_todo_list_items'] = q.call('SELECT l.title, i.issue_id, i.position, i.comment FROM issue_todo_list_items i JOIN issue_todo_lists l ON l.id=i.issue_todo_list_id ORDER BY 1,3')
out['issue_recurrences'] = q.call('SELECT issue_id, creation_mode, anchor_mode, mode, multiplier FROM issue_recurrences ORDER BY issue_id')
out['issue_digest_rules'] = q.call('SELECT id, project_id, name, schedule_type, schedule_config, timezone, recipient_modes FROM issue_digest_rules ORDER BY id')
out['view_customizes'] = q.call('SELECT id, path_pattern, customize_type, insertion_position, is_enabled FROM view_customizes ORDER BY id')
out['wiki_extensions_settings'] = q.call('SELECT project_id, auto_preview_enabled, tag_disabled, tag_dropdown_options FROM wiki_extensions_settings ORDER BY 1')
out['wiki_extensions_menus'] = q.call('SELECT project_id, menu_no, page_name, enabled FROM wiki_extensions_menus ORDER BY 1,2')
out['issue_view_columns'] = q.call('SELECT project_id, ident, "order" FROM issue_view_columns ORDER BY 1,3')
out['subtasks'] = q.call('SELECT id, parent, child, project_id, template, global FROM subtasks ORDER BY id')
out['ai_triage_provider_profiles'] = q.call('SELECT id, name, adapter, endpoint, provider_model FROM ai_triage_provider_profiles ORDER BY id')
out['issue_summaries'] = q.call('SELECT issue_id, status, summary FROM issue_summaries ORDER BY issue_id')
out['custom_fields'] = q.call('SELECT id, type, name, field_format, possible_values, format_store, multiple, is_for_all FROM custom_fields ORDER BY id')
out['itil'] = q.call("SELECT id, #{cols.call('issues').include?('impact_id') ? 'impact_id, urgency_id' : 'NULL AS impact_id, NULL AS urgency_id'} FROM issues ORDER BY id")
out['user_themes'] = q.call("SELECT user_id, others FROM user_preferences ORDER BY user_id").map { |r| { 'user_id' => r['user_id'], 'others' => r['others'].to_s.lines.grep(/ui_theme|stealth/).map(&:strip) } }

# settings: decoded values of every plugin setting (and the core ones the plugins touch)
out['settings'] = Setting.where("name LIKE 'plugin_%' OR name IN ('ui_theme','text_formatting','related_issues_default_columns','display_under_single_revision','display_under_associated_revisions','display_revision_branches_regex_enable','display_revision_branches_enable_regex_delimiters','search_token_limit','display_revision_branches','display_associated_revision_branches','revision_branches_excluded','revision_branches_enable_regex','webhooks_enabled')").order(:name).map do |s|
  v = begin
        s.value
      rescue StandardError => e
        "UNREADABLE: #{e.class}: #{e.message}"
      end
  [s.name, v.is_a?(Hash) ? JSON.parse(v.to_h.to_json) : v]
end.to_h

File.write(ENV.fetch('OUT'), JSON.pretty_generate(out))
puts "snapshot: #{out.size} sections -> #{ENV['OUT']}"
