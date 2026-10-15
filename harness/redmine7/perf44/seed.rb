# perf44 seed: realistic volume for page-performance measurement.
# Run with all plugins loaded:  RAILS_ENV=production bundle exec rails runner seed.rb
# Idempotent: the whole seed is one transaction and is skipped when it already ran.
# Bulk rows go in with insert_all (no model callbacks: no plugin side effects, no mail, no AI calls).
require 'securerandom'

R = Random.new(44)
TODAY = Date.new(2026, 10, 14)
NOW = Time.utc(2026, 10, 14, 12, 0, 0)
PASSWORD = 'Perf44pass!'

if Project.find_by(identifier: 'geo-main') && Issue.count >= 20_000
  puts "already seeded: #{Issue.count} issues, #{User.count} users"
  exit 0
end

def ins(model, rows, returning: nil)
  return [] if rows.empty?
  out = []
  rows.each_slice(2000) do |slice|
    res = model.insert_all!(slice, returning: returning, record_timestamps: false)
    out.concat(res.rows.flatten) if returning
  end
  out
end

def pick(a) = a[R.rand(a.size)]

ActiveRecord::Base.transaction do
  ActionMailer::Base.perform_deliveries = false
  Setting.rest_api_enabled = '1'
  Setting.gravatar_enabled = '0'
  Setting.per_page_options = '25,50,100'
  Setting.login_required = '0'

  admin = User.find_by(login: 'admin')
  admin.password = admin.password_confirmation = 'Perf44admin!'
  admin.must_change_passwd = false
  admin.save!

  manager, developer, reporter = Role.find_by(name: 'Manager'), Role.find_by(name: 'Developer'), Role.find_by(name: 'Reporter')
  all_perms = Redmine::AccessControl.permissions.reject(&:public?).map(&:name)
  [manager, developer].each { |r| r.permissions = (r.permissions | all_perms); r.save! }
  reporter.permissions = (reporter.permissions | Redmine::AccessControl.permissions.select { |p| p.read? }.map(&:name)); reporter.save!
  Role.non_member.tap { |r| r.permissions = r.permissions | [:view_issue_description]; r.save! }
  Role.anonymous.tap { |r| r.permissions = r.permissions | [:view_issue_description]; r.save! }

  trackers = Tracker.order(:id).to_a
  statuses = IssueStatus.order(:position).to_a
  closed = statuses.select(&:is_closed?)
  open = statuses.reject(&:is_closed?)
  priorities = IssuePriority.order(:position).to_a
  activity = TimeEntryActivity.first

  # ---- users ------------------------------------------------------------
  member1 = User.new(firstname: 'Mia', lastname: 'Member', mail: 'member1@perf44.test', language: 'en')
  member1.login = 'member1'
  member1.password = member1.password_confirmation = PASSWORD
  member1.save!
  first = %w[Anna Bert Carla Dirk Els Frank Greet Hugo Ines Jan Karel Lien Maarten Nina Olaf Pieter Quinten Rita Stijn Tine]
  last = %w[Peeters Janssens Maes Jacobs Mertens Willems Claes Goossens Wouters DeSmet Dubois Lambert Dupont Martin Simon Laurent Leroy Lemaire Michel Renard]
  rows = (1..999).map do |i|
    { login: format('user%04d', i), hashed_password: member1.hashed_password, salt: member1.salt,
      firstname: first[i % 20], lastname: "#{last[(i / 20) % 20]}#{i}", admin: false, status: (i % 50 == 0 ? 3 : 1),
      language: 'en', type: 'User', mail_notification: 'only_my_events', must_change_passwd: false,
      created_on: NOW - (1000 - i).days, updated_on: NOW, passwd_changed_on: NOW, last_login_on: NOW - R.rand(90).days }
  end
  user_ids = ins(User, rows, returning: [:id])
  ins(EmailAddress, user_ids.each_with_index.map { |id, i| { user_id: id, address: format('user%04d@perf44.test', i + 1), is_default: true, notify: true, created_on: NOW, updated_on: NOW } })
  active_ids = User.where(id: user_ids, status: 1).pluck(:id)
  all_people = [member1.id] + active_ids

  groups = %w[Staff Engineering Support Management Externals].map { |n| Group.create!(lastname: n) }
  big = groups[0]
  big_users = [member1.id] + active_ids.first(599)
  gu = big_users.map { |u| { group_id: big.id, user_id: u } }
  groups[1..].each_with_index { |g, gi| active_ids.sample(40 + 20 * gi, random: R).each { |u| gu << { group_id: g.id, user_id: u } } }
  ActiveRecord::Base.connection.execute("INSERT INTO groups_users (group_id, user_id) VALUES " + gu.uniq.map { |h| "(#{h[:group_id]},#{h[:user_id]})" }.join(','))

  # ---- projects -----------------------------------------------------------
  modules = Redmine::AccessControl.available_project_modules.map(&:to_s)
  mk = lambda do |name, ident, parent = nil|
    p = Project.new(name: name, identifier: ident, is_public: ident != 'hr-private', description: "#{name} project for performance measurement.")
    p.parent = parent if parent
    p.enabled_module_names = modules
    p.trackers = trackers
    p.save!
    p
  end
  main = mk.call('GEO Main', 'geo-main')
  subs = %w[Survey Processing Fleet Offshore Reporting].map { |n| mk.call("GEO #{n}", "geo-#{n.downcase}", main) }
  others = %w[Website Intranet Helpdesk Finance HR-Private Logistics Research Training Archive].map { |n| mk.call(n, n.downcase == 'hr-private' ? 'hr-private' : n.downcase) }
  projects = [main] + subs + others
  support = others[2]

  # ---- memberships ----------------------------------------------------------
  members = {} # [user, project] => member_id
  mroles = []
  add_member = lambda do |uid, pid|
    members[[uid, pid]] ||= Member.insert_all!([{ user_id: uid, project_id: pid, created_on: NOW, mail_notification: false }], returning: [:id], record_timestamps: false).rows[0][0]
  end
  # direct members: member1 Manager in geo-main, Reporter in the others where it is not in the group
  mroles << { member_id: add_member.call(member1.id, main.id), role_id: manager.id }
  projects.each_with_index do |p, pi|
    pool = active_ids.sample(30 + 5 * pi, random: R)
    pool.each_with_index do |u, k|
      role = k < 3 ? manager : (k.even? ? developer : reporter)
      mroles << { member_id: add_member.call(u, p.id), role_id: role.id }
    end
  end
  others.each { |p| mroles << { member_id: add_member.call(member1.id, p.id), role_id: reporter.id } unless p.identifier == 'hr-private' }
  MemberRole.insert_all!(mroles.uniq, record_timestamps: false)
  # the large group: Developer in geo-main, three subprojects, helpdesk and website; group rows plus inherited user rows
  [main, subs[0], subs[1], subs[2], support, others[0]].each do |p|
    gm = add_member.call(big.id, p.id)
    gmr = MemberRole.insert_all!([{ member_id: gm, role_id: developer.id }], returning: [:id], record_timestamps: false).rows[0][0]
    ins(Member, big_users.reject { |u| members[[u, p.id]] }.map { |u| { user_id: u, project_id: p.id, created_on: NOW, mail_notification: false } })
    Member.where(project_id: p.id, user_id: big_users).pluck(:user_id, :id).each { |u, m| members[[u, p.id]] = m }
    ins(MemberRole, big_users.map { |u| { member_id: members[[u, p.id]], role_id: developer.id, inherited_from: gmr } })
  end
  groups[1..].each_with_index do |g, gi|
    p = projects[6 + gi]
    gm = add_member.call(g.id, p.id)
    gmr = MemberRole.insert_all!([{ member_id: gm, role_id: reporter.id }], returning: [:id], record_timestamps: false).rows[0][0]
    gusers = g.user_ids
    ins(Member, gusers.reject { |u| members[[u, p.id]] }.map { |u| { user_id: u, project_id: p.id, created_on: NOW, mail_notification: false } })
    Member.where(project_id: p.id, user_id: gusers).pluck(:user_id, :id).each { |u, m| members[[u, p.id]] = m }
    ins(MemberRole, gusers.map { |u| { member_id: members[[u, p.id]], role_id: reporter.id, inherited_from: gmr } })
  end
  proj_users = projects.to_h { |p| [p.id, Member.where(project_id: p.id).joins(:principal).where(users: { type: 'User' }).pluck(:user_id)] }

  # ---- versions, categories, custom fields ---------------------------------
  versions = {}
  projects.each do |p|
    versions[p.id] = (1..4).map do |k|
      Version.create!(project: p, name: "#{p.identifier} 2026.#{k}", status: k <= 2 ? 'closed' : 'open',
                      effective_date: TODAY + (k - 3) * 45, sharing: (p == main && k == 4 ? 'descendants' : 'none'))
    end
    3.times { |k| IssueCategory.create!(project: p, name: "Category #{k + 1}") }
  end
  open_versions = versions.transform_values { |vs| vs.select { |v| v.status == 'open' } }
  cf = {}
  cf[:ref] = IssueCustomField.create!(name: 'Customer ref', field_format: 'string', is_for_all: true, is_filter: true, searchable: true, trackers: trackers)
  cf[:sev] = IssueCustomField.create!(name: 'Severity', field_format: 'list', possible_values: %w[S1 S2 S3 S4], default_value: 'S3', is_for_all: true, is_filter: true, trackers: trackers)
  cf[:comp] = IssueCustomField.create!(name: 'Components', field_format: 'list', multiple: true, possible_values: (1..10).map { |k| "Component #{k}" }, is_for_all: true, is_filter: true, trackers: trackers)
  cf[:budget] = IssueCustomField.create!(name: 'Budget', field_format: 'float', is_for_all: true, is_filter: true, visible: false, role_ids: [manager.id], trackers: trackers)
  cf[:units] = IssueCustomField.create!(name: 'Units', field_format: 'int', is_for_all: true, is_filter: true, trackers: trackers)
  cf[:target] = IssueCustomField.create!(name: 'Target date', field_format: 'date', is_for_all: true, is_filter: true, trackers: trackers)
  cf[:bill] = IssueCustomField.create!(name: 'Billable', field_format: 'bool', is_for_all: true, is_filter: true, trackers: trackers)
  cf[:rev] = IssueCustomField.create!(name: 'Reviewer', field_format: 'user', is_for_all: true, is_filter: true, trackers: trackers)
  cf[:found] = IssueCustomField.create!(name: 'Found in', field_format: 'version', is_for_all: true, is_filter: true, trackers: trackers)
  cf[:area] = IssueCustomField.create!(name: 'Area', field_format: 'enumeration', is_for_all: true, is_filter: true, trackers: trackers)
  %w[North South East West Offshore].each_with_index { |n, k| CustomFieldEnumeration.create!(custom_field: cf[:area], name: n, position: k + 1, active: true) }
  area_ids = cf[:area].enumerations.pluck(:id)

  # ---- issues ---------------------------------------------------------------
  dist = { main.id => 3000 }
  subs.each { |s| dist[s.id] = 1000 }
  others.each { |o| dist[o.id] = 12_000 / 9 + (o == others.last ? 12_000 % 9 : 0) }
  words = %w[survey vessel sensor data pipeline report invoice backup network sonar cable route crew permit gps calibration export dashboard client review]
  mkissue = lambda do |pid, parent_id = nil|
    users = proj_users[pid]
    st = R.rand < 0.35 ? pick(closed) : pick(open)
    created = NOW - R.rand(700).days - R.rand(86_400)
    dated = R.rand < 0.6
    start = dated ? TODAY - 540 + R.rand(630) : nil
    { tracker_id: pick(trackers).id, project_id: pid, subject: "#{words.sample(3, random: R).join(' ').capitalize} #{R.rand(100_000)}",
      description: "Description of the work.\n\n* point one\n* point two with #{pick(words)}\n\nSee also the #{pick(words)} notes.",
      start_date: start, due_date: start && start + 1 + R.rand(30), category_id: nil, status_id: st.id,
      assigned_to_id: R.rand < 0.2 ? nil : pick(users), priority_id: pick(priorities).id,
      fixed_version_id: R.rand < 0.5 ? pick(versions[pid]).id : nil, author_id: pick(users), lock_version: 0,
      created_on: created, updated_on: created + R.rand(30).days, done_ratio: [0, 10, 30, 50, 80, 100][R.rand(6)],
      estimated_hours: R.rand < 0.5 ? (1 + R.rand(40)).to_f : nil, parent_id: parent_id, is_private: false,
      closed_on: st.is_closed? ? created + 20.days : nil }
  end
  issue_rows = dist.flat_map { |pid, n| (n - n / 10).times.map { mkissue.call(pid) } }
  issue_ids = ins(Issue, issue_rows, returning: [:id])
  # a tenth of each project's issues are subtasks (2-4 per parent)
  child_rows = []
  dist.each do |pid, n|
    parents = Issue.where(project_id: pid).order(:id).limit(n / 10 / 3).pluck(:id)
    (n / 10).times { |k| child_rows << mkissue.call(pid, parents[k % parents.size]) }
  end
  ins(Issue, child_rows)
  Issue.rebuild_tree!
  all_issues = Issue.order(:id).pluck(:id, :project_id)
  pid_of = all_issues.to_h
  ActiveRecord::Base.connection.execute("UPDATE issues SET category_id = (SELECT min(c.id) FROM issue_categories c WHERE c.project_id = issues.project_id) + (issues.id % 3) WHERE issues.id % 4 = 0")

  # custom values
  cv = []
  all_issues.each do |iid, pid|
    users = proj_users[pid]
    cv << { customized_type: 'Issue', customized_id: iid, custom_field_id: cf[:ref].id, value: "REF-#{R.rand(99_999)}" } if R.rand < 0.7
    cv << { customized_type: 'Issue', customized_id: iid, custom_field_id: cf[:sev].id, value: %w[S1 S2 S3 S4][R.rand(4)] }
    (1 + R.rand(3)).times.map { "Component #{1 + R.rand(10)}" }.uniq.each { |v| cv << { customized_type: 'Issue', customized_id: iid, custom_field_id: cf[:comp].id, value: v } } if R.rand < 0.6
    cv << { customized_type: 'Issue', customized_id: iid, custom_field_id: cf[:budget].id, value: format('%.2f', R.rand * 10_000) } if R.rand < 0.5
    cv << { customized_type: 'Issue', customized_id: iid, custom_field_id: cf[:units].id, value: R.rand(500).to_s } if R.rand < 0.5
    cv << { customized_type: 'Issue', customized_id: iid, custom_field_id: cf[:target].id, value: (TODAY + R.rand(200) - 100).to_s } if R.rand < 0.4
    cv << { customized_type: 'Issue', customized_id: iid, custom_field_id: cf[:bill].id, value: R.rand(2).to_s }
    cv << { customized_type: 'Issue', customized_id: iid, custom_field_id: cf[:rev].id, value: pick(users).to_s } if R.rand < 0.5
    cv << { customized_type: 'Issue', customized_id: iid, custom_field_id: cf[:found].id, value: pick(versions[pid]).id.to_s } if R.rand < 0.3
    cv << { customized_type: 'Issue', customized_id: iid, custom_field_id: cf[:area].id, value: pick(area_ids).to_s } if R.rand < 0.6
  end
  ins(CustomValue, cv)

  # journals: 5 per issue on a 20% sample, plus 30 on the showcase issue
  showcase = Issue.where(project_id: main.id, parent_id: nil).where.not(fixed_version_id: nil).order(:id).first
  sample = all_issues.map(&:first).select { R.rand < 0.2 } - [showcase.id]
  jrows = []
  sample.each { |iid| 5.times { |k| jrows << [iid, k] } }
  30.times { |k| jrows << [showcase.id, k] }
  journal_rows = jrows.map do |iid, k|
    t = NOW - (60 - k).days
    { journalized_id: iid, journalized_type: 'Issue', user_id: pick(proj_users[pid_of[iid]]), notes: (k.odd? || R.rand < 0.4 ? "Note #{k}: checked the #{pick(words)} and the #{pick(words)}; see ##{pick(all_issues)[0]}." : ''),
      created_on: t, updated_on: t, private_notes: (iid == showcase.id && k % 7 == 3), updated_by_id: nil }
  end
  journal_ids = ins(Journal, journal_rows, returning: [:id])
  details = []
  journal_ids.each_with_index do |jid, n|
    iid = jrows[n][0]
    case n % 4
    when 0 then details << { journal_id: jid, property: 'attr', prop_key: 'status_id', old_value: open[0].id.to_s, value: open[1].id.to_s }
    when 1 then details << { journal_id: jid, property: 'attr', prop_key: 'assigned_to_id', old_value: pick(proj_users[pid_of[iid]]).to_s, value: pick(proj_users[pid_of[iid]]).to_s }
    when 2
      details << { journal_id: jid, property: 'cf', prop_key: cf[:sev].id.to_s, old_value: 'S3', value: 'S2' }
      details << { journal_id: jid, property: 'attr', prop_key: 'done_ratio', old_value: '10', value: '50' }
    end
  end
  ins(JournalDetail, details)

  # watchers, relations, attachments, time entries
  w = []
  all_issues.each { |iid, pid| proj_users[pid].sample(1 + R.rand(3), random: R).each { |u| w << { watchable_type: 'Issue', watchable_id: iid, user_id: u } } if R.rand < 0.5 }
  proj_users[main.id].first(8).each { |u| w << { watchable_type: 'Issue', watchable_id: showcase.id, user_id: u } }
  ins(Watcher, w.uniq { |h| [h[:watchable_id], h[:user_id]] })
  by_project = all_issues.group_by(&:last).transform_values { |a| a.map(&:first) }
  rel = []
  3000.times do
    ids = by_project[pick(projects).id]
    a, b = ids.sample(2, random: R).sort
    rel << { issue_from_id: a, issue_to_id: b, relation_type: %w[relates blocks precedes relates][R.rand(4)] }
  end
  others_main = by_project[main.id] - [showcase.id]
  5.times { |k| rel << { issue_from_id: showcase.id, issue_to_id: others_main[k * 7 + 1], relation_type: %w[relates blocks precedes relates relates][k] } }
  ins(IssueRelation, rel.uniq { |h| [h[:issue_from_id], h[:issue_to_id]] }.map { |h| h.merge(delay: h[:relation_type] == 'precedes' ? 0 : nil) })
  att = (all_issues.map(&:first).sample(3000, random: R) + [showcase.id] * 5).map do |iid|
    ext = %w[pdf txt docx xlsx][R.rand(4)]
    { container_type: 'Issue', container_id: iid, filename: "document-#{R.rand(9999)}.#{ext}", disk_filename: "perf44_#{SecureRandom.hex(8)}.#{ext}",
      filesize: 1000 + R.rand(5_000_000), content_type: { 'pdf' => 'application/pdf', 'txt' => 'text/plain', 'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }[ext],
      digest: SecureRandom.hex(32), downloads: 0, author_id: pick(proj_users[pid_of[iid]]), created_on: NOW - R.rand(300).days, description: 'perf44', disk_directory: '2026/10' }
  end
  ins(Attachment, att)
  te = all_issues.map(&:first).sample(5000, random: R).map do |iid|
    d = TODAY - R.rand(300)
    { project_id: pid_of[iid], author_id: (u = pick(proj_users[pid_of[iid]])), user_id: u, issue_id: iid, hours: (1 + R.rand(16)) / 2.0, comments: 'work',
      activity_id: activity.id, spent_on: d, tyear: d.year, tmonth: d.month, tweek: d.cweek, created_on: NOW, updated_on: NOW }
  end
  ins(TimeEntry, te)

  # ---- wiki and news (models: few rows, keep the real code paths) ----------
  projects.each do |p|
    wiki = p.wiki || Wiki.create!(project: p, start_page: 'Wiki')
    parents = []
    20.times do |k|
      title = k.zero? ? 'Wiki' : "Topic #{k}"
      page = WikiPage.new(wiki: wiki, title: title)
      page.parent = parents[(k - 1) / 4] if k.positive? && k > 4
      body = +"# #{title}\n\n{{toc}}\n\n"
      6.times do |s|
        body << "## Section #{s}\n\nText about the #{words.sample(4, random: R).join(', ')}. See [[Topic #{1 + R.rand(19)}]] and ##{pick(by_project[p.id])}.\n\n"
        body << "| a | b | c |\n|---|---|---|\n| 1 | 2 | 3 |\n\n" if s == 2
      end
      body << "{{child_pages}}\n" if k <= 4
      page.content = WikiContent.new(text: body, author_id: pick(proj_users[p.id]), comments: 'perf44')
      page.save!
      parents << page if k <= 4
    end
    3.times { |k| News.create!(project: p, title: "#{p.name} news #{k + 1}", summary: 'Summary', description: "News body #{k}", author_id: pick(proj_users[p.id])) }
  end

  # ---- plugin data -------------------------------------------------------------
  conn = ActiveRecord::Base.connection
  if conn.table_exists?('tags')
    tag_ids = (1..30).map { |k| conn.select_value("INSERT INTO tags (name) VALUES ('tag-#{k}') RETURNING id") }
    tg = []
    all_issues.each { |iid, _| tag_ids.sample(1 + R.rand(3), random: R).each { |t| tg << "(#{t},#{iid},'Issue','#{NOW.to_fs(:db)}')" } if R.rand < 0.3 }
    tg.each_slice(5000) { |s| conn.execute("INSERT INTO taggings (tag_id, taggable_id, taggable_type, created_at) VALUES #{s.join(',')}") }
    conn.execute("UPDATE issues SET cached_tag_names = sub.n FROM (SELECT taggable_id, string_agg(t.name, ', ' ORDER BY t.name) n FROM taggings g JOIN tags t ON t.id = g.tag_id WHERE taggable_type = 'Issue' GROUP BY taggable_id) sub WHERE sub.taggable_id = issues.id") if conn.column_exists?(:issues, :cached_tag_names)
  end
  if conn.table_exists?('checklists')
    ck = []
    (all_issues.map(&:first).sample(2000, random: R) + [showcase.id]).uniq.each { |iid| 4.times { |k| ck << "(#{k.odd?},'Check item #{k}',#{k + 1},#{iid},'#{NOW.to_fs(:db)}','#{NOW.to_fs(:db)}',false)" } }
    ck.each_slice(5000) { |s| conn.execute("INSERT INTO checklists (is_done, subject, position, issue_id, created_at, updated_at, is_section) VALUES #{s.join(',')}") }
  end
  if conn.table_exists?('agile_data')
    ad = all_issues.select { R.rand < 0.5 }.each_with_index.map { |(iid, _), k| "(#{iid},#{k},#{[1, 2, 3, 5, 8, 13][R.rand(6)]})" }
    ad.each_slice(5000) { |s| conn.execute("INSERT INTO agile_data (issue_id, position, story_points) VALUES #{s.join(',')}") }
  end
  if conn.table_exists?('contacts')
    contact_ids = (1..400).map do |k|
      company = k % 5 == 0
      conn.select_value("INSERT INTO contacts (first_name, last_name, company, email, is_company, author_id, created_on, updated_on, visibility) VALUES ('#{company ? "Company #{k}" : first[k % 20]}', '#{company ? '' : last[k % 20]}', 'Company #{k - k % 5}', 'contact#{k}@customer.test', #{company}, #{admin.id}, '#{NOW.to_fs(:db)}', '#{NOW.to_fs(:db)}', 0) RETURNING id")
    end
    conn.execute("INSERT INTO contacts_projects (project_id, contact_id) VALUES " + projects.flat_map { |p| contact_ids.map { |c| "(#{p.id},#{c})" } }.join(','))
    ci = (all_issues.map(&:first).sample(1000, random: R) + [showcase.id]).uniq.map { |iid| "(#{iid},#{pick(contact_ids)})" }
    conn.execute("INSERT INTO contacts_issues (issue_id, contact_id) VALUES #{ci.join(',')}")
    if conn.table_exists?('helpdesk_tickets')
      tickets = by_project[support.id].first(800)
      conn.execute("INSERT INTO helpdesk_tickets (contact_id, issue_id, source, from_address, ticket_date, is_incoming) VALUES " + tickets.map { |iid| "(#{pick(contact_ids)},#{iid},0,'contact@customer.test','#{NOW.to_fs(:db)}',true)" }.join(','))
      jm = Journal.where(journalized_type: 'Issue', journalized_id: tickets).pluck(:id).select { R.rand < 0.5 }
      conn.execute("INSERT INTO journal_messages (contact_id, journal_id, is_incoming, source, from_address, to_address, message_date) VALUES " + jm.map { |j| "(#{pick(contact_ids)},#{j},true,0,'contact@customer.test','support@perf44.test','#{NOW.to_fs(:db)}')" }.join(',')) if jm.any?
    end
  end
  if conn.table_exists?('people_information')
    dep = (1..8).map { |k| conn.select_value("INSERT INTO departments (name, lft, rgt, created_at, updated_at) VALUES ('Department #{k}', #{2 * k - 1}, #{2 * k}, '#{NOW.to_fs(:db)}', '#{NOW.to_fs(:db)}') RETURNING id") }
    pi = all_people.map { |u| "(#{u},'+32 0#{R.rand(9_999_999)}','Engineer',#{pick(dep)},false)" }
    conn.execute("INSERT INTO people_information (user_id, phone, job_title, department_id, is_system) VALUES #{pi.join(',')}")
  end

  puts "seeded: #{Issue.count} issues, #{Journal.count} journals, #{User.where(type: 'User').count} users, #{Member.count} members, #{CustomValue.count} custom values, showcase ##{showcase.id}"
end
