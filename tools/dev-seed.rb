# Seeds a development instance with enough to verify a feature against.
# Idempotent: safe to run repeatedly.
#
#   RAILS_ENV=development bundle exec ruby bin/rails runner tools/dev-seed.rb

require 'tempfile'

PASSWORD = ENV.fetch('REDMINE_ADMIN_PASSWORD', 'GEOxyzDev123!')
LONG_SUBJECT = 'Pump alignment survey report northern wind farm'

admin = User.find_by_login('admin') ||
        User.new(login: 'admin', firstname: 'Redmine', lastname: 'Admin', mail: 'admin@example.net')
admin.admin = true
admin.password = admin.password_confirmation = PASSWORD
admin.must_change_passwd = false
admin.status = User::STATUS_ACTIVE
admin.save!(validate: false)

User.current = admin

project = Project.find_by_identifier('geoxyz-verify') || Project.create!(
  name: 'GEOxyz verification', identifier: 'geoxyz-verify',
  description: 'Scratch project for browser verification of a feature.'
)
project.enabled_module_names = %w[issue_tracking wiki time_tracking repository news documents files]
project.trackers = Tracker.all
project.save!

child = Project.find_by_identifier('geoxyz-verify-sub') || Project.create!(
  name: 'GEOxyz sub', identifier: 'geoxyz-verify-sub', parent: project
)
child.enabled_module_names = %w[issue_tracking wiki]
child.trackers = Tracker.all
child.save!

%w[dev tester].each_with_index do |login, i|
  u = User.find_by_login(login) || User.new(
    login: login, firstname: login.capitalize, lastname: "Verify#{i}",
    mail: "#{login}@example.net"
  )
  u.password = u.password_confirmation = PASSWORD
  u.must_change_passwd = false
  u.status = User::STATUS_ACTIVE
  u.save!(validate: false)
  role = Role.givable.first
  Member.create!(project: project, principal: u, roles: [role]) unless u.member_of?(project)
end

group = Group.find_by_lastname('verify-group') || Group.create!(lastname: 'verify-group')
group.users << User.find_by_login('dev') unless group.users.include?(User.find_by_login('dev'))

[project, child].each do |p|
  next if p.versions.any?

  p.versions.create!(name: "#{p.identifier}-1.0", status: 'open', sharing: 'none')
end

if project.issues.count < 6
  status_open = IssueStatus.where(is_closed: false).first
  (project.issues.count...6).each do |n|
    Issue.create!(
      project: project, tracker: Tracker.first, author: admin,
      status: status_open, priority: IssuePriority.first,
      subject: "Verification issue #{n + 1}",
      assigned_to: (n.even? ? User.find_by_login('dev') : nil)
    )
  end
end

# A subject with seven distinct words, so a text filter can be given more than
# the five tokens the search engine caps at.
unless project.issues.exists?(subject: LONG_SUBJECT)
  Issue.create!(
    project: project, tracker: Tracker.first, author: admin,
    status: IssueStatus.where(is_closed: false).first, priority: IssuePriority.first,
    subject: LONG_SUBJECT
  )
end

project.create_wiki!(start_page: 'Wiki') if project.wiki.nil?
wiki = project.wiki

# Assigning an empty WikiContent to a persisted page saves it immediately and
# fails validation, so build it with its text and author already set.
def upsert_wiki_page(wiki, title, text, author, parent = nil)
  page = wiki.find_page(title) || WikiPage.new(wiki: wiki, title: title)
  page.parent = parent if parent
  if page.content
    page.content.text = text
    page.content.author = author
  else
    page.content = WikiContent.new(text: text, author: author)
  end
  page.save!
  page
end

root = upsert_wiki_page(wiki, 'Wiki', "h1. Wiki\n\nRoot page for verification.", admin)
%w[Child_one Child_two].each do |title|
  upsert_wiki_page(wiki, title, "h1. #{title}\n\nChild page for verification.", admin, root)
end

# Wiki attachments, so an export that claims to carry them has something to
# carry. Two files share a name on purpose: that is the collision case.
def upsert_wiki_attachment(page, filename, body, author)
  return if page.attachments.any? {|a| a.filename == filename && a.filesize == body.bytesize}

  file = Tempfile.new(['seed', File.extname(filename)])
  file.binmode
  file.write(body)
  file.rewind
  attachment = Attachment.new(container: page, author: author, filename: filename)
  attachment.file = file
  attachment.filename = filename
  attachment.save!
ensure
  file&.close!
end

upsert_wiki_attachment(root, 'notes.txt', "Notes attached to the root wiki page.\n", admin)
child_one = wiki.find_page('Child_one')
upsert_wiki_attachment(child_one, 'diagram.txt', "First diagram.\n", admin)
upsert_wiki_attachment(child_one, 'diagram.txt', "Second diagram, same filename.\n", admin)

puts "seeded: projects=#{Project.count} users=#{User.count} issues=#{Issue.count} " \
     "wiki_pages=#{WikiPage.count} wiki_attachments=#{Attachment.where(container_type: 'WikiPage').count} " \
     "versions=#{Version.count} groups=#{Group.count}"
puts "login: admin / #{PASSWORD}"
