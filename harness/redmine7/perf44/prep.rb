# Writes config.json for measure.rb: API keys, showcase issue, context-menu ids, custom field ids.
require 'json'
main = Project.find_by!(identifier: 'geo-main')
admin = User.find_by!(login: 'admin'); m1 = User.find_by!(login: 'member1')
cm = Issue.where(project_id: main.self_and_descendants.ids).open.order(:id).limit(40).pluck(:id).each_slice(4).map(&:first)
cfs = IssueCustomField.order(:id).pluck(:name, :id).to_h
q = IssueQuery.new(project: main)
cfg = { admin_key: admin.api_key, member_key: m1.api_key, showcase: 1, journals_on_showcase: Journal.where(journalized_id: 1).count,
        context_ids: cm, cf: cfs, project: main.identifier,
        project_columns_all: q.available_columns.map { |c| c.name.to_s } }
File.write(File.join(ENV['P'], 'config.json'), JSON.pretty_generate(cfg))
puts cfg.except(:project_columns_all).to_json
puts cfg[:project_columns_all].join(' ')
