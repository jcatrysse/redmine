# Write smoke on the upgraded 7.0: change data that came from 5.1 through the 7.0 plugins' models.
#   bundle exec rails runner 52_write70.rb   (RAILS_ENV=production)
$results = []
def section(name)
  print "-- #{name} ... "
  r = ActiveRecord::Base.transaction(requires_new: true) { yield }
  puts "ok #{r}"
  $results << [name, "ok #{r}"]
rescue Exception => e
  puts "WRITE-FAIL #{e.class}: #{e.message.lines.first&.strip}"
  puts e.backtrace.select { |l| l.include?('/plugins/') || l.include?('/app/') }.first(4).map { |l| "     #{l}" }
  $results << [name, "FAIL #{e.class}: #{e.message.lines.first&.strip}"]
end
admin = User.find_by_login('admin'); bob = User.find_by_login('bob'); alice = User.find_by_login('alice')
User.current = bob
main = Project.find_by(identifier: 'geo-main'); hd = Project.find_by(identifier: 'helpdesk')

section 'core+custom_workflows: new issue in geo-main gets the [GEO] prefix (5.1 workflow script)' do
  is = Issue.new(project: main, tracker: Tracker.find_by(name: 'Bug'), author: bob, subject: 'Created on 7.0', priority: IssuePriority.default || IssuePriority.first)
  is.custom_field_values = { IssueCustomField.find_by(name: 'Severity').id => 'Low' }
  is.save!
  raise "subject #{is.subject.inspect}" unless is.subject.start_with?('[GEO]')
  is.subject
end

section 'core: edit a 5.1 issue (journal, status, custom field)' do
  is = Issue.find(1)
  is.init_journal(bob, 'Edited on 7.0')
  is.custom_field_values = { IssueCustomField.find_by(name: 'Customer ref').id => 'REF-7000' }
  is.save!
  "journals=#{is.journals.count}"
end

section 'redmine_checklists: add and tick items on a 5.1 issue' do
  is = Issue.find(1)
  Checklist.create!(issue: is, subject: 'Added on 7.0 ' + ('y' * 700), position: 9)
  c = is.checklists.where(is_section: false).first
  c.update!(is_done: !c.is_done)
  "items=#{is.checklists.count}"
end

section 'redmineup_tags: retag a 5.1 issue, cache follows' do
  is = Issue.find(2)
  is.tag_list = %w[upgraded survey]
  is.save!
  "cached=#{is.reload.cached_tag_names}"
end

section 'redmine_contacts_helpdesk: customer reply to a 5.1 ticket lands on the same issue' do
  t = HelpdeskTicket.order(:id).last
  before = t.issue.journals.count
  raw = "From: #{t.from_address}\r\nTo: support@geoxyz.invalid\r\nSubject: Re: #{t.issue.subject}\r\nMessage-ID: <upgrade-reply@client.invalid>\r\n" \
        "In-Reply-To: <#{t.message_id}>\r\nReferences: <#{t.message_id}>\r\nDate: #{Time.now.rfc2822}\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\nReply after the upgrade\r\n"
  ok = HelpdeskMailer.receive(raw, issue: { project: 'helpdesk' })
  after = t.issue.reload.journals.count
  raise "receive=#{ok.inspect} journals #{before}->#{after}" unless after == before + 1
  jm = JournalMessage.order(:id).last
  "issue=#{t.issue_id} journals #{before}->#{after} journal_message contact=#{jm.contact_id}"
end

section 'redmine_contacts_helpdesk: new ticket by mail on 7.0 (long Cc)' do
  cc = (1..40).map { |i| "person#{i}@client.invalid" }.join(', ')
  raw = "From: New Customer <newcust@client.invalid>\r\nTo: support@geoxyz.invalid\r\nCc: #{cc}\r\nSubject: New on 7.0\r\nMessage-ID: <upgrade-new@client.invalid>\r\n" \
        "Date: #{Time.now.rfc2822}\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\nHello\r\n"
  n = HelpdeskTicket.count
  HelpdeskMailer.receive(raw, issue: { project: 'helpdesk' })
  raise "no ticket created (#{n} -> #{HelpdeskTicket.count})" unless HelpdeskTicket.count == n + 1
  t = HelpdeskTicket.order(:id).last
  "ticket=#{t.id} contact=#{t.contact&.email} cc_length=#{t.cc_address.to_s.size}"
end

section 'redmine_agile: move a 5.1 issue into a 5.1 sprint' do
  ad = AgileData.find_or_initialize_by(issue_id: 3)
  ad.agile_sprint_id = AgileSprint.find_by(name: 'Sprint 2').id
  ad.story_points = 13
  ad.save!
  "sprint=#{ad.agile_sprint_id}"
end

section 'redmine_contacts: note on a 5.1 contact, deal status change' do
  c = Contact.where(is_company: false).first
  ContactNote.create!(source: c, subject: '7.0', content: 'Note after upgrade', author: bob)
  d = Deal.first
  d.status = DealStatus.where.not(id: d.status_id).first
  d.save!
  "contact=#{c.id} deal=#{d.id} processes=#{DealProcess.where(deal_id: d.id).count}"
end

section 'redmine_people: day off for a 5.1 person' do
  Dayoff.create!(user_id: alice.id, leave_type: LeaveType.first, approved: false, start_date: Date.new(2027, 2, 1), end_date: Date.new(2027, 2, 2), hours_per_day: 8)
  PeopleAnnouncement.first.tap { |a| a.description = a.description + ' (7.0)'; a.save! }
  "dayoffs=#{Dayoff.count}"
end

section 'redmine_issue_todo_lists2: add a 7.0 issue to a 5.1 list' do
  l = IssueTodoList.find_by(title: 'Release checklist')
  IssueTodoListItem.create!(issue_todo_list: l, issue: Issue.order(:id).last, position: 99)
  "items=#{l.issue_todo_list_items.count}"
end

section 'redmine_mail_digest: load and validate the 5.1 rules' do
  IssueDigestRule.all.map { |r| "#{r.name}:#{r.valid? ? 'valid' : r.errors.full_messages.join('/')}" }.join(', ')
end

section 'core webhooks: the 5.1 webhook is usable on 7.0' do
  w = Webhook.first
  raise 'no webhook' unless w
  "events=#{w.events.inspect} projects=#{w.project_ids.inspect} trackers=#{w.tracker_ids.size} valid=#{w.valid?} #{w.errors.full_messages.join('/')}"
end

section 'redmine_project_workflows: 0.0.3 rules readable through the 0.1 model' do
  s = ProjectWorkflowScope.all.map { |x| [x.project_id, x.tracker_id, x.role_id, x.rule_type] }
  "scopes=#{s.size}"
end

puts
puts 'WRITE SUMMARY'
$results.each { |n, r| puts "#{r.start_with?('ok') ? 'OK  ' : 'FAIL'} #{n} -- #{r}" }
