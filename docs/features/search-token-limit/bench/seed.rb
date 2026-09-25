# Build a realistically sized issue table for the token-limit benchmark.
require 'securerandom'

N = (ENV['N'] || 50_000).to_i
srand 42

admin = User.find_by(login: 'admin') || User.create!(
  login: 'admin', firstname: 'A', lastname: 'D', mail: 'admin@example.net',
  admin: true, password: 'GEOxyzDev123!', password_confirmation: 'GEOxyzDev123!'
)
User.current = admin
project = Project.find_by(identifier: 'bench') || Project.create!(name: 'Bench', identifier: 'bench')
project.trackers = Tracker.all
project.save!
tracker = Tracker.first
status  = IssueStatus.first
prio    = IssuePriority.first || Enumeration.create!(type: 'IssuePriority', name: 'Normal', is_default: true)

# A vocabulary big enough that a term is selective, plus a set of "common"
# words that appear in every row - those are the worst case for AND, because
# every LIKE has to be evaluated instead of failing on the first one.
VOCAB  = (1..400).map {|i| "term#{i}"}
COMMON = (1..60).map  {|i| "common#{i}"}

now = Time.now
rows = []
N.times do |i|
  words = VOCAB.sample(8) + COMMON
  subject = "Issue #{i} " + words.sample(12).join(' ')
  description = words.shuffle.join(' ') + ' ' + VOCAB.sample(40).join(' ')
  rows << {
    tracker_id: tracker.id, project_id: project.id, subject: subject,
    description: description, author_id: admin.id, status_id: status.id,
    priority_id: prio.id, created_on: now, updated_on: now, lft: 1, rgt: 2
  }
  if rows.size >= 5_000
    Issue.insert_all!(rows)
    rows = []
    print '.'
  end
end
Issue.insert_all!(rows) if rows.any?
puts
puts "issues: #{Issue.count}"
Issue.connection.execute('ANALYZE issues')
