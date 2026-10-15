# Seed the 5.1 database (r70h_upg) through the 5.1 plugins' own models, so that every plugin table that
# production fills holds rows. Run on a fresh r70h_upg (12_db51.sh) with:
#   RAILS_ENV=production bundle exec rails runner $S/20_seed51.rb
# Each section is isolated: an error is printed (SEED-FAIL) and the next section runs.
require 'stringio'

ActionMailer::Base.delivery_method = :test
ActionMailer::Base.perform_deliveries = false
$results = []

def section(name)
  print "-- #{name} ... "
  ActiveRecord::Base.transaction(requires_new: true) { yield }
  puts 'ok'
  $results << [name, 'ok']
rescue Exception => e
  puts "SEED-FAIL #{e.class}: #{e.message.lines.first&.strip}"
  puts e.backtrace.select { |l| l.include?('/plugins/') || l.include?('20_seed51') }.first(4).map { |l| "     #{l}" }
  $results << [name, "FAIL #{e.class}: #{e.message.lines.first&.strip}"]
end

admin = User.find_by_login('admin')
User.current = admin
Setting.default_language = 'en'
Setting.text_formatting = 'common_mark'
Setting.rest_api_enabled = '1'
Setting.mail_from = 'redmine@geoxyz.invalid'

# ---------------------------------------------------------------- core
section 'core: users, group, roles' do
  %w[alice bob carol dave erin].each_with_index do |login, i|
    next if User.find_by_login(login)
    u = User.new(firstname: login.capitalize, lastname: 'Tester', mail: "#{login}@geoxyz.invalid", language: 'en')
    u.login = login
    u.password = u.password_confirmation = 'Upgrade-Rehearsal-2026'
    u.admin = false
    u.save!
  end
  g = Group.find_by(lastname: 'Support team') || Group.create!(lastname: 'Support team')
  g.users << User.find_by_login('dave') unless g.users.include?(User.find_by_login('dave'))
  g.users << User.find_by_login('erin') unless g.users.include?(User.find_by_login('erin'))
  all_perms = Redmine::AccessControl.permissions.reject(&:public?).map(&:name)
  mgr = Role.find_by(name: 'Manager')
  mgr.permissions = all_perms
  mgr.save!
  dev = Role.find_by(name: 'Developer')
  dev.permissions = (dev.permissions + all_perms.select { |p| p.to_s =~ /view|add|edit_own|checklist|agile|tag|todo|template|contacts|deal|helpdesk|send_response|summary|issue_description|inline/ }).uniq
  dev.save!
  rep = Role.find_by(name: 'Reporter')
  rep.permissions = (rep.permissions + all_perms.select { |p| p.to_s =~ /^view_/ }).uniq
  rep.save!
end

section 'core: projects (one with subprojects), modules, members, versions, categories' do
  mods = Redmine::AccessControl.available_project_modules.map(&:to_s)
  trackers = Tracker.all.to_a
  mk = lambda do |identifier, name, parent = nil, public = true|
    p = Project.find_by(identifier: identifier) || Project.new(identifier: identifier, name: name, is_public: public)
    p.parent = parent if parent
    p.tracker_ids = trackers.map(&:id)
    p.enabled_module_names = mods
    p.save!
    p
  end
  main = mk.call('geo-main', 'GEO Main')
  sub1 = mk.call('geo-sub1', 'GEO Survey', main)
  sub2 = mk.call('geo-sub2', 'GEO Lab', main, false)
  hd = mk.call('helpdesk', 'Helpdesk', nil, false)
  crm = mk.call('crm', 'CRM', nil, false)
  roles = Role.where(name: %w[Manager Developer Reporter]).index_by(&:name)
  [main, sub1, sub2, hd, crm].each do |p|
    { 'bob' => 'Manager', 'alice' => 'Developer', 'carol' => 'Reporter', 'dave' => 'Developer' }.each do |login, rn|
      u = User.find_by_login(login)
      Member.create!(project: p, principal: u, role_ids: [roles[rn].id]) unless Member.where(project: p, user_id: u.id).exists?
    end
    g = Group.find_by(lastname: 'Support team')
    Member.create!(project: p, principal: g, role_ids: [roles['Developer'].id]) unless Member.where(project: p, user_id: g.id).exists?
  end
  v1 = Version.create!(project: main, name: '2026.1', sharing: 'tree', effective_date: Date.new(2026, 12, 31))
  Version.create!(project: main, name: '2026.2', sharing: 'none')
  Version.create!(project: sub1, name: 'Survey Q4', sharing: 'descendants')
  Version.create!(project: hd, name: 'HD backlog')
  IssueCategory.create!(project: main, name: 'Backend', assigned_to: User.find_by_login('alice'))
  IssueCategory.create!(project: hd, name: 'Mail')
end

section 'core: issue custom fields' do
  IssueCustomField.create!(name: 'Customer ref', field_format: 'string', is_for_all: true, tracker_ids: Tracker.ids, is_filter: true)
  IssueCustomField.create!(name: 'Severity', field_format: 'list', possible_values: %w[Low Medium High], is_for_all: true,
                           tracker_ids: Tracker.ids, is_filter: true, default_value: 'Medium')
  IssueCustomField.create!(name: 'Reviewer', field_format: 'user', is_for_all: true, tracker_ids: Tracker.ids)
  IssueCustomField.create!(name: 'Area', field_format: 'list', possible_values: %w[North South], multiple: true,
                           is_for_all: true, tracker_ids: Tracker.ids)
  ProjectCustomField.create!(name: 'Cost centre', field_format: 'string')
  UserCustomField.create!(name: 'Employee no', field_format: 'string')
end

section 'core: issues, journals, relations, watchers, time entries, attachments' do
  main = Project.find_by(identifier: 'geo-main')
  sub1 = Project.find_by(identifier: 'geo-sub1')
  sub2 = Project.find_by(identifier: 'geo-sub2')
  hd = Project.find_by(identifier: 'helpdesk')
  crm = Project.find_by(identifier: 'crm')
  alice = User.find_by_login('alice'); bob = User.find_by_login('bob'); carol = User.find_by_login('carol')
  sev = IssueCustomField.find_by(name: 'Severity'); ref = IssueCustomField.find_by(name: 'Customer ref')
  rev = IssueCustomField.find_by(name: 'Reviewer'); area = IssueCustomField.find_by(name: 'Area')
  v1 = Version.find_by(name: '2026.1')
  bug = Tracker.find_by(name: 'Bug'); feat = Tracker.find_by(name: 'Feature'); sup = Tracker.find_by(name: 'Support')
  issues = []
  [[main, bug], [main, feat], [main, sup], [sub1, bug], [sub1, feat], [sub2, bug], [sub2, sup], [hd, sup], [crm, feat], [main, bug]].each_with_index do |(p, t), i|
    is = Issue.new(project: p, tracker: t, author: [alice, bob, carol][i % 3], subject: "Seed issue #{i + 1} (#{p.identifier})",
                   description: "Description of seed issue #{i + 1}.\n\n* point a\n* point b", priority: IssuePriority.all[i % 4],
                   assigned_to: (i.even? ? alice : nil), start_date: Date.new(2026, 10, 1) + i, due_date: Date.new(2026, 11, 1) + i,
                   estimated_hours: i + 1, fixed_version: ([main, sub1, sub2].include?(p) ? v1 : nil))
    is.custom_field_values = { sev.id => %w[Low Medium High][i % 3], ref.id => "REF-#{1000 + i}", rev.id => bob.id.to_s, area.id => %w[North South] }
    is.save!
    issues << is
  end
  child = Issue.new(project: main, tracker: feat, author: bob, subject: 'Seed child of issue 2', parent_issue_id: issues[1].id)
  child.save!
  issues << child
  IssueRelation.create!(issue_from: issues[0], issue_to: issues[1], relation_type: 'relates')
  IssueRelation.create!(issue_from: issues[3], issue_to: issues[4], relation_type: 'blocks')
  IssueRelation.create!(issue_from: issues[0], issue_to: issues[9], relation_type: 'duplicates')
  issues.first(6).each_with_index do |is, i|
    User.current = [bob, alice][i % 2]
    is.reload.init_journal(User.current, "Note #{i + 1} on #{is.subject}")
    is.status = IssueStatus.find_by(name: 'In Progress') if i.even?
    is.done_ratio = 30
    is.save!
    is.reload.init_journal(User.current, 'Private follow-up').tap { |j| j.private_notes = true }
    is.save!
  end
  User.current = admin
  issues[2].reload.tap { |is| is.init_journal(admin, 'Closing'); is.status = IssueStatus.find_by(name: 'Closed'); is.save! }
  issues.first(4).each { |is| Watcher.create!(watchable: is, user: carol) }
  issues.first(5).each_with_index { |is, i| TimeEntry.create!(project: is.project, issue: is, user: alice, hours: i + 0.5, spent_on: Date.new(2026, 10, 10), activity: TimeEntryActivity.first, comments: 'seed work') }
  issues.first(3).each_with_index do |is, i|
    a = Attachment.new(container: is, author: alice, file: StringIO.new("seed attachment #{i}\n" * 20), filename: "seed-#{i}.txt", content_type: 'text/plain', description: 'seed file')
    a.save!
  end
end

section 'core: wiki pages' do
  %w[geo-main geo-sub1].each do |ident|
    p = Project.find_by(identifier: ident)
    w = p.wiki || Wiki.create!(project: p, start_page: 'Wiki')
    %w[Wiki Procedures Contacts].each_with_index do |title, i|
      page = WikiPage.new(wiki: w, title: title)
      page.parent = w.find_page('Wiki') if i > 0
      page.content = WikiContent.new(text: "h1. #{title}\n\nSeed text for #{title} in #{ident}.\n\n{{tags}}", author: User.find_by_login('bob'))
      page.save!
    end
  end
end

# ---------------------------------------------------------------- redmine_contacts
section 'redmine_contacts: contacts, deals, notes, addresses, statuses, categories, queries, tags' do
  crm = Project.find_by(identifier: 'crm'); hd = Project.find_by(identifier: 'helpdesk')
  bob = User.find_by_login('bob')
  ds_open = DealStatus.find_by(name: 'Pending') || DealStatus.create!(name: 'Pending', status_type: DealStatus::OPEN_STATUS, is_default: true)
  ds_won = DealStatus.find_by(name: 'Won') || DealStatus.create!(name: 'Won', status_type: DealStatus::WON_STATUS)
  ds_lost = DealStatus.find_by(name: 'Lost') || DealStatus.create!(name: 'Lost', status_type: DealStatus::LOST_STATUS)
  crm.deal_statuses = [ds_open, ds_won, ds_lost] if crm.respond_to?(:deal_statuses=)
  cat = DealCategory.create!(name: 'Consulting', project: crm)
  company = Contact.new(first_name: 'GeoCorp', is_company: true, email: 'info@geocorp.invalid', phone: '+32 3 000 00 00', author: bob, visibility: 1)
  company.projects = [crm, hd]
  company.tag_list = 'customer, vip' if company.respond_to?(:tag_list=)
  company.save!
  people = 3.times.map do |i|
    c = Contact.new(first_name: "Contact#{i}", last_name: 'Person', company: 'GeoCorp', email: "contact#{i}@geocorp.invalid",
                    job_title: 'Engineer', author: bob, assigned_to: bob, visibility: 0)
    c.projects = [crm, hd]
    c.tag_list = 'customer' if c.respond_to?(:tag_list=)
    c.address = Address.new(street1: "Street #{i}", city: 'Antwerp', postcode: '2000', country_code: 'BE', address_type: 'business') if c.respond_to?(:address=)
    c.save!
    c
  end
  deals = 3.times.map do |i|
    d = Deal.new(name: "Seed deal #{i}", project: crm, author: bob, assigned_to: bob, status: [ds_open, ds_won, ds_lost][i],
                 contact: people[i], category: cat, price: 1000 * (i + 1), currency: 'EUR', probability: 50, due_date: Date.new(2026, 12, 1))
    d.save!
    d.related_contacts << company
    d
  end
  deals[0].reload.update!(status: ds_won)
  DealProcess.create!(deal: deals[0], author: bob, old_value: ds_open.id, value: ds_won.id) if DealProcess.where(deal_id: deals[0].id).none?
  people.each { |c| ContactNote.create!(source: c, subject: 'Call', content: "Called #{c.name}", author: bob) }
  deals.each { |d| DealNote.create!(source: d, subject: 'Offer', content: "Offer for #{d.name}", author: bob) }
  crm_issue = Issue.where(project_id: crm.id).first
  ActiveRecord::Base.connection.execute("INSERT INTO contacts_issues (issue_id, contact_id) VALUES (#{crm_issue.id}, #{people[0].id})")
  ActiveRecord::Base.connection.execute("INSERT INTO deals_issues (issue_id, deal_id) VALUES (#{crm_issue.id}, #{deals[0].id})")
  ContactQuery.create!(name: 'Customers in Antwerp', project: crm, user: bob, visibility: 2, filters: { 'tags' => { operator: '=', values: ['customer'] } })
  DealQuery.create!(name: 'Open deals', project: crm, user: bob, visibility: 2, filters: { 'status_id' => { operator: 'o', values: [''] } })
end

# ---------------------------------------------------------------- redmine_contacts_helpdesk
def hd_mail(from:, subject:, body:, message_id:, in_reply_to: nil, cc: nil, to: 'support@geoxyz.invalid')
  m = +"From: #{from}\r\nTo: #{to}\r\n"
  m << "Cc: #{cc}\r\n" if cc
  m << "Subject: #{subject}\r\nMessage-ID: <#{message_id}>\r\nDate: #{Time.now.rfc2822}\r\n"
  m << "In-Reply-To: <#{in_reply_to}>\r\nReferences: <#{in_reply_to}>\r\n" if in_reply_to
  m << "MIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n#{body}\r\n"
end

section 'redmine_contacts_helpdesk: project settings, tickets via HelpdeskMailer.receive, replies, journal messages' do
  hd = Project.find_by(identifier: 'helpdesk')
  ContactsSetting['helpdesk_answer_from', hd.id] = 'support@geoxyz.invalid'
  ContactsSetting['helpdesk_tracker', hd.id] = Tracker.find_by(name: 'Support').id.to_s
  ContactsSetting['helpdesk_assigned_to', hd.id] = User.find_by_login('dave').id.to_s
  ContactsSetting['helpdesk_enable_reopen_lock', hd.id] = '1'
  ContactsSetting['helpdesk_add_email_watchers', hd.id] = '1'
  ContactsSetting['helpdesk_send_notification', hd.id] = '0'
  Setting.plugin_redmine_contacts_helpdesk = (Setting.plugin_redmine_contacts_helpdesk || {}).merge('helpdesk_issue_reply_scope' => 'project')
  ok = 0
  5.times do |i|
    r = HelpdeskMailer.receive(hd_mail(from: "Customer #{i} <cust#{i}@client.invalid>", subject: "Help needed #{i}", body: "Our survey data #{i} is missing.",
                                       message_id: "seed-#{i}@client.invalid", cc: (i.zero? ? 'boss@client.invalid, other@client.invalid' : nil)),
                               issue: { project: 'helpdesk' })
    ok += 1 if r
  end
  raise "only #{ok}/5 tickets received (see log/production.log)" if ok < 5
  2.times do |i|
    HelpdeskMailer.receive(hd_mail(from: "Customer #{i} <cust#{i}@client.invalid>", subject: "Re: Help needed #{i}", body: "Any news #{i}?",
                                   message_id: "seed-reply-#{i}@client.invalid", in_reply_to: "seed-#{i}@client.invalid"), issue: { project: 'helpdesk' })
  end
  dave = User.find_by_login('dave')
  HelpdeskTicket.joins(:issue).where(issues: { project_id: hd.id }).limit(3).each_with_index do |t, i|
    is = t.issue
    j = is.init_journal(dave, "Agent answer #{i}")
    is.save!
    JournalMessage.create!(journal: j, contact: t.customer, is_incoming: false, from_address: 'support@geoxyz.invalid',
                           to_address: t.from_address, cc_address: t.cc_address, message_date: Time.now, message_id: "agent-#{i}@geoxyz.invalid", source: 0)
  end
  t = HelpdeskTicket.order(:id).first
  t.reopen_locked = true if t.respond_to?(:reopen_locked=)
  t.vote = 2; t.vote_comment = 'Fine'
  t.save!
end

section 'redmine_contacts_helpdesk: canned responses, mail rules (GEOxyz conditions/actions), saved queries with customer filter' do
  hd = Project.find_by(identifier: 'helpdesk'); bob = User.find_by_login('bob')
  CannedResponse.create!(name: 'Thanks', content: 'Dear {%contact.first_name%}, thanks for your mail.', project: hd, user: bob, is_public: true)
  CannedResponse.create!(name: 'Global close', content: 'We close this ticket.', project: nil, user: User.find_by_login('admin'), is_public: true)
  rules = [
    [0, { 'to_address' => { operator: '~', values: ['support@'] }, 'has_attachment' => { operator: '=', values: ['1'] } }, { 'assignee' => { values: [bob.id.to_s] } }],
    [0, { 'cc_address' => { operator: '*~', values: ['boss@'] } }, { 'email_watchers' => { values: ['1'] }, 'stop' => { values: ['1'] } }],
    [0, { 'message_subject' => { operator: '^', values: ['SPAM'] } }, { 'discard' => { values: ['1'] } }],
    [1, { 'issue_closed' => { operator: '=', values: ['1'] }, 'current_status' => { operator: '=', values: [IssueStatus.find_by(name: 'Closed').id.to_s] } }, { 'reopen_status' => { values: [IssueStatus.find_by(name: 'In Progress').id.to_s] } }],
    [0, { 'delivered_to_address' => { operator: '~', values: ['geoxyz'] }, 'mail_priority' => { operator: '=', values: ['high'] } }, { 'priority' => { values: [IssuePriority.last.id.to_s] } }]
  ]
  rules.each_with_index do |(type, cond, act), i|
    r = HelpdeskMailRule.new(mail_type: type, user: User.find_by_login('admin'), position: i + 1)
    r.conditions = cond
    r.actions = act
    r.save!
  end
  IssueQuery.create!(name: 'HD by customer', project: hd, user: bob, visibility: 2,
                     filters: { 'status_id' => { operator: 'o', values: [''] }, 'customer' => { operator: '=', values: [Contact.where(is_company: false).first.id.to_s] } },
                     column_names: [:tracker, :subject, :customer, :customer_company, :status])
  IssueQuery.create!(name: 'HD by company (global)', project: nil, user: bob, visibility: 2,
                     filters: { 'customer_company' => { operator: '~', values: ['GeoCorp'] } }, column_names: [:subject, :customer_company])
  HelpdeskTicketQuery.create!(name: 'HD tickets', project: hd, user: bob, visibility: 2, filters: { 'status_id' => { operator: 'o', values: [''] } }) if defined?(HelpdeskTicketQuery)
end

# ---------------------------------------------------------------- redmine_agile
section 'redmine_agile: sprints, agile data, colors, saved boards' do
  main = Project.find_by(identifier: 'geo-main')
  s1 = AgileSprint.create!(project: main, name: 'Sprint 1', status: AgileSprint::CLOSED, start_date: Date.new(2026, 9, 1), end_date: Date.new(2026, 9, 14), sharing: 0)
  s2 = AgileSprint.create!(project: main, name: 'Sprint 2', status: AgileSprint::ACTIVE, start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 14), sharing: 1)
  AgileSprint.create!(project: main, name: 'Sprint 3', status: AgileSprint::OPEN, start_date: Date.new(2026, 10, 15), end_date: Date.new(2026, 10, 28), sharing: 4) rescue AgileSprint.create!(project: main, name: 'Sprint 3', status: AgileSprint::OPEN, start_date: Date.new(2026, 10, 15), end_date: Date.new(2026, 10, 28))
  main.issues.order(:id).each_with_index do |is, i|
    ad = AgileData.find_or_initialize_by(issue_id: is.id)
    ad.position = i
    ad.story_points = [1, 2, 3, 5, 8][i % 5]
    ad.agile_sprint_id = [s1.id, s2.id, 0][i % 3]
    ad.save!
  end
  AgileColor.create!(container: main.issues.first, color: 'red')
  AgileColor.create!(container: Tracker.first, color: 'green') rescue nil
  AgileColor.create!(container: IssuePriority.first, color: 'blue') rescue nil
  q = AgileQuery.new(name: 'Team board', project: main, user: User.find_by_login('bob'), visibility: 2)
  q.filters = { 'status_id' => { operator: '*', values: [''] } }
  q.column_names = [:project, :assigned_to, :story_points] rescue nil
  q.options[:group_by] = 'assigned_to' rescue nil
  q.save!
  gq = AgileQuery.new(name: 'Public all-projects board', project: nil, user: User.find_by_login('admin'), visibility: 2)
  gq.filters = { 'status_id' => { operator: 'o', values: [''] } }
  gq.save!
  if defined?(AgileChartsQuery)
    cq = AgileChartsQuery.new(name: 'Burndown main', project: main, user: User.find_by_login('bob'), visibility: 2)
    cq.save!
  end
end

# ---------------------------------------------------------------- redmine_checklists
section 'redmine_checklists: checklist items, sections, templates, categories' do
  main = Project.find_by(identifier: 'geo-main')
  main.issues.order(:id).first(5).each_with_index do |is, i|
    Checklist.create!(issue: is, subject: 'Preparation', is_section: true, position: 1)
    Checklist.create!(issue: is, subject: "Check item A of #{is.id}", is_done: i.even?, position: 2)
    Checklist.create!(issue: is, subject: "Check item B of #{is.id} " + ('x' * 300), is_done: false, position: 3)
  end
  cat = ChecklistTemplateCategory.create!(name: 'Survey', position: 1)
  ChecklistTemplate.create!(name: 'Survey prep', project: main, category: cat, user: User.find_by_login('bob'), is_public: true,
                            template_items: "Calibrate\nPack\nTravel", is_default: true, tracker_id: Tracker.find_by(name: 'Bug').id)
  ChecklistTemplate.create!(name: 'Global QA', project: nil, category: cat, user: User.find_by_login('admin'), is_public: true, template_items: "Review\nSign off")
  Setting.plugin_redmine_checklists = (Setting.plugin_redmine_checklists || {}).merge('save_log' => '1', 'issue_done_ratio' => '0', 'enable_check_all' => '1')
end

# ---------------------------------------------------------------- redmineup_tags
section 'redmineup_tags: issue tags' do
  Issue.order(:id).each_with_index do |is, i|
    is.reload
    is.tag_list = [%w[survey], %w[urgent lab], %w[helpdesk], %w[survey lab]][i % 4]
    is.save!
  end
  IssueQuery.create!(name: 'By tag', project: nil, user: User.find_by_login('bob'), visibility: 2,
                     filters: { 'issue_tags' => { operator: '=', values: ['survey'] } }, column_names: [:subject, :tags_relations], group_by: 'tags_relations') rescue
    IssueQuery.create!(name: 'By tag', project: nil, user: User.find_by_login('bob'), visibility: 2, filters: { 'issue_tags' => { operator: '=', values: ['survey'] } }, column_names: [:subject, :tags])
end

# ---------------------------------------------------------------- redmine_people
section 'redmine_people: departments, information, leave types, dayoffs, holidays, announcements, experiences' do
  bob = Person.find(User.find_by_login('bob').id)
  root = Department.create!(name: 'Operations', head_id: bob.id)
  survey = Department.create!(name: 'Survey', parent_id: root.id)
  %w[alice bob carol dave].each_with_index do |login, i|
    u = User.find_by_login(login)
    info = PeopleInformation.find_or_initialize_by(user_id: u.id)
    info.assign_attributes(phone: "+32 470 00 00 0#{i}", job_title: 'Surveyor', department_id: (i.even? ? survey.id : root.id), manager_id: (login == 'bob' ? nil : bob.id),
                           birthday: Date.new(1990, 1, 1 + i), appearance_date: Date.new(2020, 1, 1), workday_length: 8, gender: i % 2)
    info.save!
  end
  lt = LeaveType.create!(name: 'Vacation', color: '#00ff00', paid: true, approvable: true)
  LeaveType.create!(name: 'Sick', color: '#ff0000', paid: true, approvable: false)
  Dayoff.create!(user_id: User.find_by_login('alice').id, leave_type: lt, approved: true, start_date: Date.new(2026, 12, 24), end_date: Date.new(2026, 12, 31), hours_per_day: 8, notes: 'Xmas')
  PeopleHoliday.create!(name: 'New year', start_date: Date.new(2027, 1, 1), is_workday: false)
  PeopleAnnouncement.create!(description: 'Office closed Friday', start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 12, 1), frequency: 'once', kind: 'warning', active: true, department_id: survey.id)
  PeopleAnnouncement.create!(description: 'All hands', start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 12, 1), frequency: 'once', kind: 'notice', active: true)
  PeopleWorkExperience.create!(user_id: User.find_by_login('alice').id, previous_company_name: 'OldCo', job_title: 'Junior', from_date: Date.new(2015, 1, 1), to_date: Date.new(2019, 12, 31))
  bob.tag_list = 'lead' if bob.respond_to?(:tag_list=)
  bob.save!
end

# ---------------------------------------------------------------- redmine_custom_workflows
section 'redmine_custom_workflows: issue, project and shared workflows' do
  main = Project.find_by(identifier: 'geo-main')
  CustomWorkflow.create!(name: 'Default subject prefix', observable: 'issue', active: true, is_for_all: false, projects: [main],
                         before_save: "self.subject = \"[GEO] \#{subject}\" if new_record? && !subject.to_s.start_with?('[GEO]')", author: 'jan.catrysse@geoxyz.eu')
  CustomWorkflow.create!(name: 'Shared helpers', observable: 'shared', active: true, shared_code: "class CwHelper; def self.ok?; true; end; end")
  CustomWorkflow.create!(name: 'Project name check', observable: 'project', active: false, is_for_all: true, before_save: "errors.add(:name, 'bad') if name.to_s.include?('forbidden')")
  CustomWorkflow.create!(name: 'Group users log', observable: 'group_users', active: true, before_add: "Rails.logger.info('cw add')")
end

# ---------------------------------------------------------------- redmine_project_workflows (0.0.3: rows in workflows with project_id)
section 'redmine_project_workflows (0.0.3): project-specific transitions and field permissions' do
  main = Project.find_by(identifier: 'geo-main'); sub1 = Project.find_by(identifier: 'geo-sub1')
  dev = Role.find_by(name: 'Developer'); mgr = Role.find_by(name: 'Manager')
  bug = Tracker.find_by(name: 'Bug'); feat = Tracker.find_by(name: 'Feature')
  st = IssueStatus.sorted.to_a
  [[main, bug, dev], [main, feat, mgr], [sub1, bug, dev]].each do |p, t, r|
    pairs = [[0, st[0]], [st[0], st[1]], [st[1], st[2]], [st[2], st[4]], [st[1], st[4]]]
    pairs << [st[0], st[5]] if p == sub1
    pairs.each do |from, to|
      WorkflowTransition.create!(project_id: p.id, tracker_id: t.id, role_id: r.id, old_status_id: (from == 0 ? 0 : from.id), new_status_id: to.id)
    end
    WorkflowPermission.create!(project_id: p.id, tracker_id: t.id, role_id: r.id, old_status_id: st[1].id, field_name: 'due_date', rule: 'readonly')
    WorkflowPermission.create!(project_id: p.id, tracker_id: t.id, role_id: r.id, old_status_id: st[0].id, field_name: IssueCustomField.find_by(name: 'Severity').id.to_s, rule: 'required')
  end
  # a duplicate row as older installations carry (deduplicate task)
  WorkflowTransition.create!(project_id: main.id, tracker_id: bug.id, role_id: dev.id, old_status_id: st[0].id, new_status_id: st[1].id)
end

# ---------------------------------------------------------------- redmine_issue_templates
section 'redmine_issue_templates: project, global, note templates, settings' do
  main = Project.find_by(identifier: 'geo-main'); bob = User.find_by_login('bob'); bug = Tracker.find_by(name: 'Bug')
  IssueTemplate.create!(project: main, tracker: bug, author: bob, title: 'Field bug', issue_title: 'Bug: ', description: "Steps:\n1.\n2.", enabled: true, is_default: true,
                        checklist_json: ['Reproduce', 'Fix'], builtin_fields_json: { 'priority_id' => IssuePriority.first.id.to_s })
  IssueTemplate.create!(project: main, tracker: Tracker.find_by(name: 'Feature'), author: bob, title: 'Feature request', description: 'Why:', enabled: true, enabled_sharing: true)
  g = GlobalIssueTemplate.create!(title: 'Global bug', tracker: bug, author: User.find_by_login('admin'), description: 'Global template', enabled: true, is_default: false)
  g.projects = [main, Project.find_by(identifier: 'geo-sub1')]
  IssueTemplateSetting.create!(project: main, help_message: 'Pick a template', enabled: true, should_replaced: true, inherit_templates: false)
  IssueTemplateSetting.create!(project: Project.find_by(identifier: 'geo-sub1'), enabled: true, inherit_templates: true)
  NoteTemplate.create!(project: main, tracker: bug, author: bob, name: 'Need info', description: 'Please send logs.', enabled: true, visibility: 'open', position: 1)
  nt = NoteTemplate.new(project: main, tracker: bug, author: bob, name: 'Managers only', description: 'Internal.', enabled: true, visibility: 'roles', position: 2)
  nt.role_ids = [Role.find_by(name: 'Manager').id]
  nt.save!
  gn = GlobalNoteTemplate.new(name: 'Global note', description: 'Global note text', tracker: bug, author: User.find_by_login('admin'), enabled: true, visibility: 'open', position: 1)
  gn.projects = [main]
  gn.save!
end

# ---------------------------------------------------------------- redmine_issue_todo_lists2
section 'redmine_issue_todo_lists2: lists and items' do
  main = Project.find_by(identifier: 'geo-main'); bob = User.find_by_login('bob')
  l = IssueTodoList.create!(project: main, title: 'Release checklist', description: 'Things before release', created_by: bob, last_updated_by: bob, last_updated: Time.now)
  main.issues.open.order(:id).first(4).each_with_index { |is, i| IssueTodoListItem.create!(issue_todo_list: l, issue: is, position: i + 1, comment: "item #{i}") }
  IssueTodoListItem.create!(issue_todo_list: l, issue: nil, position: 5, comment: 'Free text line')
  IssueTodoList.create!(project: main, title: 'Empty list', created_by: bob, last_updated_by: bob, last_updated: Time.now, remove_closed_issues: true)
end

# ---------------------------------------------------------------- issue_recurring
section 'issue_recurring: recurrences' do
  main = Project.find_by(identifier: 'geo-main')
  is = main.issues.open.order(:id).first
  IssueRecurrence.create!(issue: is, creation_mode: 'copy_first', anchor_mode: 'first_issue_fixed', mode: 'weekly', multiplier: 1,
                          delay_mode: 'days', delay_multiplier: 0, include_subtasks: false, anchor_to_start: false, count: 0)
  is2 = main.issues.open.order(:id).detect { |x| x.leaf? && x.parent_id.nil? && x.id != is.id }
  IssueRecurrence.create!(issue: is2, creation_mode: 'reopen', anchor_mode: 'last_issue_flexible', mode: 'monthly_day_from_first', multiplier: 1,
                          delay_mode: 'days', delay_multiplier: 0, include_subtasks: false, anchor_to_start: true, count: 0)
  Setting.plugin_issue_recurring = (Setting.plugin_issue_recurring || {}).merge('author_id' => '0', 'keep_assignee' => 'false', 'journal_mode' => 'never', 'copy_recurrence' => 'true', 'ahead_multiplier' => '0', 'ahead_mode' => 'days')
end

# ---------------------------------------------------------------- redmine_mail_digest
section 'redmine_mail_digest: digest rules, runs, deliveries' do
  main = Project.find_by(identifier: 'geo-main'); bob = User.find_by_login('bob')
  r1 = IssueDigestRule.create!(project: main, name: 'Weekly overview', schedule_type: 'weekly', schedule_config: { 'day' => 1 },
                               send_time: '08:00', timezone: 'Europe/Brussels', recipient_modes: %w[project_members], created_by: bob,
                               include_open: true, include_overdue: true, group_by: 'assignee')
  IssueDigestRule.create!(project: main, name: 'Daily due soon', schedule_type: 'daily', schedule_config: {}, send_time: '07:30', timezone: 'Etc/GMT+12',
                          recipient_modes: ["user:#{bob.id}", 'assignees'], created_by: bob, include_due_soon: true, due_soon_days: 3, include_subprojects: true)
  run = IssueDigestRun.create!(issue_digest_rule: r1, schedule_key: '2026-W41', status: 'success', trigger: 'manual', started_at: Time.now - 3600,
                               finished_at: Time.now, recipients_count: 1, emails_sent_count: 1, issues_count: 3)
  IssueDigestDelivery.create!(issue_digest_run: run, email: 'bob@geoxyz.invalid', user_id: bob.id, status: 'sent', issues_count: 3, sent_at: Time.now)
end

# ---------------------------------------------------------------- redmine_ai_summary
section 'redmine_ai_summary: project settings, summaries' do
  main = Project.find_by(identifier: 'geo-main')
  AiSummaryProjectSetting.create!(project: main, subtask_summary_max_depth: 2, auto_generate: false, model: 'gpt-4o-mini', system_prompt: 'Summarise.', max_completion_tokens: 500)
  main.issues.order(:id).first(2).each { |is| IssueSummary.create!(issue: is, summary: "Summary of #{is.subject}", status: 'up_to_date', created_by: 1, updated_by: 1) }
end

# ---------------------------------------------------------------- redmine_ai_triage
section 'redmine_ai_triage: provider profile, project provider, prompt, template, policy, routing, workload, attachment rule, stats panel' do
  main = Project.find_by(identifier: 'geo-main'); bob = User.find_by_login('bob')
  M = RedmineAiTriage
  pp = M::ProviderProfile.new(name: 'Local LLM', adapter: (M::ProviderProfile::ADAPTERS.include?('openai_compatible') ? 'openai_compatible' : M::ProviderProfile::ADAPTERS.first),
                              endpoint: 'http://127.0.0.1:9/v1', provider_model: 'test-model', schema_version: 1)
  pp.save!
  M::ProjectProvider.create!(project_id: main.id, provider_profile_id: pp.id)
  M::PromptTemplate.create!(name: 'Triage basic', text: 'Classify this issue.', position: 0)
  pr = M::Prompt.create!(project_id: main.id)
  pr.update_text!('Project prompt text', author: bob)
  M::Policy.create!(project_id: main.id, name: 'Default policy', state: (M::Policy::STATES.include?('draft') ? 'draft' : M::Policy::STATES.first), position: 0, schema_version: 1)
  M::RoutingProfile.create!(project_id: main.id, user_id: User.find_by_login('alice').id, notes: 'Survey specialist')
  M::WorkloadModel.create!(project_id: main.id, weighting: M::WorkloadModel::WEIGHTINGS.first, target: 10, unestimated_weight: 1) rescue M::WorkloadModel.create!(project_id: main.id, weighting: M::WorkloadModel::WEIGHTINGS.first)
  M::AttachmentRule.create!(project_id: main.id, name: 'Images', position: 0, disclosure: M::AttachmentRule::DISCLOSURES.first)
  M::StatsPanel.create!(project_id: main.id, owner_login: 'bob')
end

# ---------------------------------------------------------------- view_customize
section 'view_customize: scripts' do
  ViewCustomize.create!(path_pattern: '/issues', code: "$(function(){ $('#loggedas').append(' (GEO)'); });", customize_type: 'javascript', insertion_position: 'html_bottom', comments: 'touches #loggedas', author_id: 1, is_enabled: true)
  ViewCustomize.create!(path_pattern: '.*', code: '.icon-edit { background-image: url(../images/edit.png); }', customize_type: 'css', insertion_position: 'html_head', comments: 'legacy icon css', author_id: 1)
  ViewCustomize.create!(path_pattern: '/issues/[0-9]+', project_pattern: 'geo-.*', code: '<div class="geo-banner">GEO</div>', customize_type: 'html', insertion_position: 'issue_show', comments: 'banner', author_id: 1, is_private: false)
end

# ---------------------------------------------------------------- redmine_wiki_extensions
section 'redmine_wiki_extensions: settings, menus, tags, comments, counts, votes' do
  main = Project.find_by(identifier: 'geo-main')
  pages = main.wiki.pages.to_a
  WikiExtensionsSetting.create!(project_id: main.id, auto_preview_enabled: true, tag_disabled: false, tag_dropdown_options: "survey\nlab")
  WikiExtensionsMenu.create!(project_id: main.id, menu_no: 1, page_name: 'Procedures', title: 'Procedures', enabled: true)
  WikiExtensionsMenu.create!(project_id: main.id, menu_no: 2, page_name: 'Contacts', title: 'Contacts', enabled: false)
  WikiExtensionsMenu.create!(project_id: main.id, menu_no: 0, page_name: 'Orphan', title: 'forward_wiki_page leftover', enabled: true)
  tag = WikiExtensionsTag.create!(project_id: main.id, name: 'procedure')
  WikiExtensionsTagRelation.create!(tag_id: tag.id, wiki_page_id: pages[1].id)
  c = WikiExtensionsComment.create!(wiki_page_id: pages[0].id, user_id: User.find_by_login('alice').id, comment: 'Nice page')
  WikiExtensionsComment.create!(wiki_page_id: pages[0].id, user_id: User.find_by_login('bob').id, comment: 'Reply', parent_id: c.id)
  pages.each_with_index { |pg, i| WikiExtensionsCount.create!(project: main, page: pg, date: Date.new(2026, 10, 1), count: 3 + i) }
  WikiExtensionsVote.create!(keystr: 'poll1', target_class_name: 'WikiPage', target_id: pages[0].id, count: 4)
end

# ---------------------------------------------------------------- redmine_issue_view_columns
section 'redmine_issue_view_columns: global and project columns' do
  main = Project.find_by(identifier: 'geo-main')
  s = (Setting.plugin_redmine_issue_view_columns || {}).to_h
  s['issue_view_default_columns'] = %w[status assigned_to due_date done_ratio]
  s['relations_display_limit'] = '20'
  Setting.plugin_redmine_issue_view_columns = s
  %w[tracker subject status priority assigned_to].each_with_index { |c, i| IssueViewColumns.create!(project_id: main.id, ident: c, order: i + 1) }
end

# ---------------------------------------------------------------- redmine_ldap_sync (no server)
section 'redmine_ldap_sync: auth source and sync settings' do
  as = AuthSourceLdap.create!(name: 'GEO AD', host: 'ldap.geoxyz.invalid', port: 389, base_dn: 'dc=geoxyz,dc=local', attr_login: 'sAMAccountName',
                              attr_firstname: 'givenName', attr_lastname: 'sn', attr_mail: 'mail', onthefly_register: true, account: 'svc', account_password: 'secret')
  User.find_by_login('erin').update!(auth_source_id: as.id)
  ls = LdapSetting.find_by_auth_source_ldap_id(as.id)
  ls.safe_attributes = { 'active' => '1', 'class_user' => 'user', 'class_group' => 'group', 'groupname' => 'cn', 'member' => 'member', 'user_memberid' => 'dn',
                         'group_membership' => 'on_groups', 'nested_groups' => '', 'sync_on_login' => 'user_fields_and_groups', 'dyngroups' => '',
                         'users_search_scope' => 'subtree', 'account_flags' => 'userAccountControl', 'required_group' => 'redmine-users', 'admin_group' => 'redmine-admins',
                         'create_groups' => '1', 'create_users' => '1', 'groupname_pattern' => 'redmine', 'group_search_filter' => '(objectClass=group)' }
  ls.save or raise "ldap setting not saved: #{ls.errors.full_messages.join(', ')}"
end

# ---------------------------------------------------------------- redmine_subtask
section 'redmine_subtask: rules' do
  main = Project.find_by(identifier: 'geo-main')
  Subtask.create!(parent: Tracker.find_by(name: 'Feature').id, child: Tracker.find_by(name: 'Bug').id, project_id: main.id, default: true, auto: false,
                  template: IssueTemplate.first&.id, global: false, inheritance: true, custom_fields: nil)
  Subtask.create!(parent: Tracker.find_by(name: 'Support').id, child: Tracker.find_by(name: 'Bug').id, project_id: main.id, default: false, auto: true,
                  template: GlobalIssueTemplate.first&.id, global: true, inheritance: false, custom_fields: [IssueCustomField.find_by(name: 'Severity').id.to_s].to_json)
end

# ---------------------------------------------------------------- redmine_zenedit
section 'redmine_zenedit: drafts, viewings' do
  is = Issue.order(:id).first
  ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql_array(
    ["INSERT INTO drafts (target_type, user_id, parent_type, parent_id, data, updated_at) VALUES ('Journal', ?, 'Issue', ?, ?, now())",
     User.find_by_login('alice').id, is.id, ActiveRecord::Base.connection.escape_bytea(Marshal.dump({ notes: 'draft note' }))]))
  ActiveRecord::Base.connection.execute("INSERT INTO viewings (viewer_id, viewed_id, viewed_type, ip, created_at) VALUES (#{User.find_by_login('bob').id}, #{is.id}, 'Issue', '127.0.0.1', now())")
end

# ---------------------------------------------------------------- reporter dashboards
section 'redmine_reporter_dashboards: template, version, share link, project tab' do
  main = Project.find_by(identifier: 'geo-main')
  T = RedmineReporterDashboards::Template
  t = T.new(name: 'Weekly status', project: main, author: User.find_by_login('bob'), visibility: T::VISIBILITIES.last,
            source: T::SOURCES.first, output: T::OUTPUTS.first, orientation: 'portrait', page_size: T::PAGE_SIZES.first)
  t.content = '<h1>{{ project.name }}</h1>{% for issue in issues %}<p>{{ issue.subject }}</p>{% endfor %}'
  t.save!
  RedmineReporterDashboards::TemplateVersion.create!(template_id: t.id, author_id: t.author_id, content: t.content,
                                                     content_digest: RedmineReporterDashboards::TemplateVersion.digest_for(t.content))
  RedmineReporterDashboards::ShareLink.create_with_token!(template_id: t.id, project_id: main.id, scope_kind: 'query', expires_at: Time.now + 30.days,
                                                          created_by_id: t.author_id, render_as_user_id: t.author_id, purpose: 'seed')
  ReporterProjectTab.create!(project_id: main.id, title: 'Status', position: 1, layout: [{ 'template_id' => t.id }], settings: { 'visible' => true })
end

# ---------------------------------------------------------------- custom fields of plugins
section 'custom fields: depending list (dcf), computed, sql, itil impact/urgency on issues' do
  parent = IssueCustomField.find_by(name: 'Severity')
  dl = IssueCustomField.new(name: 'Sub severity', field_format: 'depending_list', possible_values: %w[Minor Major Blocker], is_for_all: true, tracker_ids: Tracker.ids)
  dl.parent_custom_field_id = parent.id if dl.respond_to?(:parent_custom_field_id=)
  dl.value_dependencies = { 'Low' => ['Minor'], 'Medium' => %w[Minor Major], 'High' => %w[Major Blocker] } if dl.respond_to?(:value_dependencies=)
  dl.save!
  cc = IssueCustomField.new(name: 'Hours left', field_format: 'float', is_computed: true, formula: '(estimated_hours || 0) - (spent_hours || 0)', is_for_all: true, tracker_ids: Tracker.ids)
  cc.save!
  sq = IssueCustomField.new(name: 'Contact pick', field_format: 'sql', is_for_all: true, tracker_ids: Tracker.ids)
  sq.sql = 'SELECT first_name FROM contacts ORDER BY 1'
  sq.save!
  # as the field form stores them (form_params, search_by_click, strict_selection always submitted)
  ss = IssueCustomField.new(name: 'Contact search', field_format: 'sql_search', is_for_all: true, tracker_ids: Tracker.ids)
  ss.sql = "SELECT id AS value, first_name AS label FROM contacts WHERE first_name ILIKE '%%%{q}%%' ORDER BY 2"
  ss.form_params = "q=issue_subject\n"; ss.search_by_click = '1'; ss.strict_selection = '0'; ss.strict_error_message = 'not valid'
  ss.save!
  sl = IssueCustomField.new(name: 'Contact search legacy', field_format: 'sql_search', is_for_all: true, tracker_ids: Tracker.ids)
  sl.sql = "SELECT id AS value, first_name AS label FROM contacts WHERE first_name ILIKE '%%%<q>s%%' ORDER BY 2"
  sl.form_params = "q=issue_subject\n"; sl.search_by_click = '0'; sl.strict_selection = '0'; sl.strict_error_message = 'not valid'
  sl.save!
  Issue.order(:id).first(6).each_with_index do |is, i|
    Issue.where(id: is.id).update_all(impact_id: (i % 3) + 1, urgency_id: ((i + 1) % 3) + 1) if Issue.column_names.include?('impact_id')
  end
  Issue.order(:id).first(3).each { |is| is.reload; is.custom_field_values = { dl.id => { 'Low' => 'Minor', 'Medium' => 'Major', 'High' => 'Blocker' }[is.custom_field_value(parent)] }; is.save! }
end

# ---------------------------------------------------------------- per-user plugin preferences
section 'user preferences: user_specific_theme, stealth, people' do
  { 'alice' => 'alternate', 'bob' => 'PurpleMine2', 'carol' => 'classic' }.each do |login, theme|
    u = User.find_by_login(login)
    pref = u.pref
    pref.others = (pref.others || {}).merge(ui_theme: theme)
    pref.save!
  end
  u = User.find_by_login('dave'); pref = u.pref; pref.others = (pref.others || {}).merge(stealth_mode: true); pref.save!
  Setting.ui_theme = 'alternate'
end

# ---------------------------------------------------------------- parent/child filter saved queries
section 'redmine_parent_child_filters: saved issue query with its filters' do
  IssueQuery.create!(name: 'Open parents of bugs', project: Project.find_by(identifier: 'geo-main'), user: User.find_by_login('bob'), visibility: 2,
                     filters: { 'parent_status_id' => { operator: 'o', values: [''] }, 'child_tracker_id' => { operator: '=', values: [Tracker.find_by(name: 'Bug').id.to_s] } },
                     column_names: [:tracker, :subject, :parent, :status])
end

# ---------------------------------------------------------------- core extras: webhooks (5.1-stable-GEOxyz feature), news, documents, forums
section 'core 5.1-GEOxyz webhooks, news, documents, forums' do
  main = Project.find_by(identifier: 'geo-main'); bob = User.find_by_login('bob')
  Setting.webhooks_enabled = '1'
  w = Webhook.new(user: User.find_by_login('admin'), url: 'https://hooks.geoxyz.invalid/redmine', secret: 's3cret', active: true, events: %w[issue.created issue.updated])
  w.projects = [main, Project.find_by(identifier: 'helpdesk')]
  w.trackers = Tracker.all.to_a if w.respond_to?(:trackers=)
  w.save!
  n = News.create!(project: main, author: bob, title: 'Seed news', summary: 'sum', description: 'News body')
  Comment.create!(commented: n, author: User.find_by_login('alice'), content: 'Nice')
  Document.create!(project: main, category: DocumentCategory.first, title: 'Seed document', description: 'doc')
  b = Board.create!(project: main, name: 'General', description: 'Forum')
  Message.create!(board: b, author: bob, subject: 'Hello', content: 'First post')
end

puts
puts 'SEED SUMMARY'
$results.each { |n, r| puts "#{r == 'ok' ? 'OK  ' : 'FAIL'} #{n}#{r == 'ok' ? '' : " -- #{r}"}" }
