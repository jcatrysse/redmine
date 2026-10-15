# What users get from the workflows, per project set (project, tracker, role) that has its own rules on 5.1 plus
# the same tracker/role in a project without own rules: for every status (0 = new issue) the statuses offered,
# the read-only and the required fields. Based on jira2redmine_migration tools/testenv/workflow_fingerprint.rb.
#   SETS=sets.json OUT=answers.json bundle exec rails runner 32_wf_fingerprint.rb
# Without SETS the sets are computed (5.1 run) and written to SETS_OUT. Users and issues are rolled back.
require 'json'
if ENV['SETS'].present?
  sets = JSON.parse(File.read(ENV['SETS']))
else
  sets = WorkflowRule.where.not(project_id: nil).distinct.pluck(:project_id, :tracker_id, :role_id)
  plain = Project.where.not(id: sets.map(&:first)).where(identifier: 'geo-sub2').first
  sets |= sets.map { |_, t, r| [plain.id, t, r] } if plain
  File.write(ENV.fetch('SETS_OUT'), JSON.generate(sets.sort))
end
statuses = IssueStatus.sorted.to_a
answers = {}
ActiveRecord::Base.transaction do
  users = {}
  sets.sort.each do |project_id, tracker_id, role_id|
    project = Project.find(project_id)
    user = users[[project_id, role_id]] ||= begin
      u = User.new(firstname: 'Fingerprint', lastname: 'Proof', mail: "fp.#{project_id}.#{role_id}@example.invalid")
      u.login = "fp_#{project_id}_#{role_id}"
      u.password = u.password_confirmation = 'Proof-2026-only'
      u.save!
      Member.create!(project: project, user: u, role_ids: [role_id])
      u
    end
    fresh = Issue.new(project: project, tracker_id: tracker_id, author: user, subject: 'fingerprint')
    answers["#{project_id}|#{tracker_id}|#{role_id}|0"] = {
      'offered' => fresh.new_statuses_allowed_to(user).map(&:id).sort,
      'readonly' => fresh.read_only_attribute_names(user).sort, 'required' => fresh.required_attribute_names(user).sort
    }
    issue = Issue.new(project: project, tracker_id: tracker_id, author: user, subject: 'fingerprint', status: statuses.first)
    issue.save!(validate: false)
    statuses.each do |status|
      Issue.where(id: issue.id).update_all(status_id: status.id)
      i = Issue.find(issue.id)
      answers["#{project_id}|#{tracker_id}|#{role_id}|#{status.id}"] = {
        'offered' => i.new_statuses_allowed_to(user).map(&:id).sort,
        'readonly' => i.read_only_attribute_names(user).sort, 'required' => i.required_attribute_names(user).sort
      }
    end
  end
  raise ActiveRecord::Rollback
end
File.write(ENV.fetch('OUT'), JSON.pretty_generate(answers.sort.to_h))
puts "sets=#{sets.size} answers=#{answers.size} offered=#{answers.values.sum { |a| a['offered'].size }} readonly=#{answers.values.sum { |a| a['readonly'].size }} required=#{answers.values.sum { |a| a['required'].size }}"
