# ruby fix_check.rb  -> per landed fix: the query count it targets, before vs after, from the traced runs
# (median-free: average per request over the traced repetitions), for both all-plugins and core.
require 'json'
D = __dir__
def load(f) = File.readlines(f).map { |l| JSON.parse(l) }
TR = {
  'before all' => load(File.join(D, 'before', 'trace-alltr.jsonl')),
  'after all' => load(File.join(D, 'logs', 'trace-alltr2.jsonl')),
  'before core' => load(File.join(D, 'before', 'trace-coretr.jsonl')),
  'after core' => load(File.join(D, 'logs', 'trace-coretr2.jsonl'))
}.freeze
def count(recs, page, user, re)
  rs = recs.select { |r| _, u, pg, = r['label'].split('|'); pg == page && u == user }
  return nil if rs.empty?
  rs.sum { |r| r['sql'].select { |e| e['fp'] =~ re }.sum { |e| e['n'] } } / rs.size.to_f
end
CHECKS = [
  ['core #44252 journal_details preload', 'activity', 'member1', /FROM "journal_details" WHERE "journal_details"\."journal_id" = \$\?/],
  ['core group-membership preload (groups of a user)', 'issue_show', 'member1', /INNER JOIN "groups_users" ON "users"\."id" = "groups_users"\."group_id" WHERE .*"groups_users"\."user_id" = \$\?/],
  ['people avatar map (avatar attachments)', 'calendar', 'member1', /"attachments"\."container_type" = \$\? AND \(attachments\.description = \?\)/],
  ['people avatar map (avatar attachments)', 'activity', 'member1', /"attachments"\."container_type" = \$\? AND \(attachments\.description = \?\)/],
  ['people avatar map (avatar attachments)', 'agile_board', 'member1', /"attachments"\."container_type" = \$\? AND \(attachments\.description = \?\)/],
  ['people avatar map (avatar attachments)', 'gantt', 'member1', /"attachments"\."container_type" = \$\? AND \(attachments\.description = \?\)/],
  ['people avatar map (avatar attachments)', 'issue_show', 'member1', /"attachments"\."container_type" = \$\? AND \(attachments\.description = \?\)/],
  ['agile colour-mode check / card user preload', 'agile_board', 'member1', /FROM "agile_colors"/],
  ['agile sprint column preload', 'issues_plugcols_100', 'admin', /FROM "agile_sprints" INNER JOIN "agile_data"/],
  ['tags column preload', 'issues_plugcols_100', 'admin', /FROM "tags" INNER JOIN "taggings"/],
  ['checklists column preload', 'issues_plugcols_100', 'admin', /FROM "checklists" WHERE "checklists"\."issue_id" = \$\?/],
  ['todo_lists2 column preload', 'issues_plugcols_100', 'admin', /FROM "issue_todo_lists" INNER JOIN "issue_todo_list_items"/],
  ['itil per-request settings (enabled_modules per project)', 'issues_25', 'member1', /SELECT "enabled_modules"\.\* FROM "enabled_modules" WHERE "enabled_modules"\."project_id" = \$\?/],
  ['itil per-request settings (enabled_modules per project)', 'api_issues_100', 'admin', /SELECT "enabled_modules"\.\* FROM "enabled_modules" WHERE "enabled_modules"\."project_id" = \$\?/],
  ['project_workflows context-menu memo (workflow queries)', 'context_menu', 'member1', /"workflows"|"project_workflow_scopes"|"issue_statuses"\."id" IN \(SELECT "workflows"/],
  ['helpdesk Issue#author (NOT fixed)', 'activity', 'member1', /FROM "users" WHERE "users"\."type" IN \(\$\?, \$\?, \$\?\) AND "users"\."id" = \$\? ORDER BY/],
  ['helpdesk journal_message per journal (NOT fixed)', 'issue_show', 'member1', /FROM "journal_messages" WHERE "journal_messages"\."journal_id" = \$\?/],
  ['helpdesk columns per row (NOT fixed)', 'issues_plugcols_100', 'admin', /FROM "helpdesk_tickets" WHERE "helpdesk_tickets"\."issue_id" = \$\?|FROM "contacts" INNER JOIN "helpdesk_tickets"/],
  ['vid visible_condition membership.project (NOT fixed)', 'issues_25', 'member1', /SELECT "projects"\.\* FROM "projects" WHERE "projects"\."id" = \$\? LIMIT \$\?/]
].freeze
puts '| fix | page@user | all: before -> after | core: before -> after |'
puts '|---|---|---|---|'
CHECKS.each do |name, page, user, re|
  v = TR.transform_values { |recs| count(recs, page, user, re) }
  f = ->(x) { x.nil? ? '-' : format('%.0f', x) }
  puts "| #{name} | #{page}@#{user} | #{f.(v['before all'])} -> #{f.(v['after all'])} | #{f.(v['before core'])} -> #{f.(v['after core'])} |"
end
