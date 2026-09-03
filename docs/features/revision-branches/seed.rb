# Adds a Git repository with several branches to the dev instance, so the
# revision page and the issue's associated revisions have something to show.
#
#   tools/dev-server.sh /home/user/wt/<worktree>
#   bundle exec ruby bin/rails runner -e development \
#     /home/user/redmine/docs/features/revision-branches/seed.rb
#
# Idempotent.

REPO_PATH = '/tmp/redmine-dev-git/demo.git'
WORK_PATH = '/tmp/redmine-dev-git/demo'
GIT = 'git -c user.name=Dev -c user.email=dev@example.com -c init.defaultBranch=main'

unless File.directory?(REPO_PATH)
  FileUtils.mkdir_p(File.dirname(REPO_PATH))
  raise 'git init failed' unless system("#{GIT} init --quiet #{WORK_PATH}")

  File.write("#{WORK_PATH}/README", "Demo repository\n")
  system("cd #{WORK_PATH} && #{GIT} add README && #{GIT} commit --quiet -m 'Initial import'")
  File.write("#{WORK_PATH}/CHANGELOG", "Nothing yet\n")
  system("cd #{WORK_PATH} && #{GIT} add CHANGELOG && #{GIT} commit --quiet -m 'Adds a changelog'")
  ['release/7.0', 'dependabot/bundler/rails-8.1.4', '12345-add-revision-branches', 'wip/experiment'].each do |branch|
    system("cd #{WORK_PATH} && #{GIT} branch #{branch}")
  end
  system("cd #{WORK_PATH} && #{GIT} checkout --quiet 12345-add-revision-branches")
  File.write("#{WORK_PATH}/branches.txt", "Only on the feature branch\n")
  system("cd #{WORK_PATH} && #{GIT} add branches.txt && #{GIT} commit --quiet -m 'Shows the branches of a revision'")
  system("cd #{WORK_PATH} && #{GIT} checkout --quiet main")
  raise 'git clone --bare failed' unless system("#{GIT} clone --quiet --bare #{WORK_PATH} #{REPO_PATH}")
end

# Repository.scm_available is false unless config/configuration.yml names a
# path regexp for the SCM, and Repository validates its type against the
# available adapters — so without this the Git repository cannot be created.
#
# It goes in the `development:` section on purpose. test/test_helper.rb sets
# every scm_*_path_regexp to '.*' with ||=, so a value under `default:` wins
# over that and makes every Git repository in the test suite invalid — 46
# failures in RepositoriesGitControllerTest that look like the patch's fault.
#
# Redmine reads configuration.yml at boot, so restart the dev server when this
# writes something.
config = Rails.root.join('config/configuration.yml')
unless File.read(config).include?('scm_git_path_regexp')
  File.write(config, "#{File.read(config).rstrip}\n\ndevelopment:\n  scm_git_path_regexp: /tmp/redmine-dev-git/.*\n")
  abort "wrote scm_git_path_regexp to #{config} — restart the dev server and run this again"
end

# The dev database ships with enabled_scm empty, and Repository validates its
# type against that list too.
Setting.enabled_scm = (Setting.enabled_scm | ['Git'])

project = Project.find_by!(identifier: 'geoxyz-verify')
project.enable_module!('repository')

repository = Repository::Git.find_by(project_id: project.id, identifier: 'demo')
repository ||=
  Repository::Git.create!(project: project, identifier: 'demo',
                          url: REPO_PATH, path_encoding: 'UTF-8',
                          is_default: true)
repository.fetch_changesets
repository.reload

# A user who may read issues but not changesets. Changeset.visible filters on
# :view_changesets, so this user gets no Associated revisions tab at all, which
# is the gate the branch display inherits.
role = Role.find_by(name: 'Issue reader') || Role.create!(name: 'Issue reader')
role.update!(permissions: [:view_issues])
reader = User.find_by(login: 'norepo') ||
         User.create!(login: 'norepo', firstname: 'No', lastname: 'Changesets',
                      mail: 'norepo@example.net',
                      password: 'GEOxyzDev123!', password_confirmation: 'GEOxyzDev123!')
reader.update!(status: User::STATUS_ACTIVE, must_change_passwd: false)
member = Member.find_by(project_id: project.id, user_id: reader.id) ||
         Member.new(project: project, principal: reader)
member.roles = [role]
member.save!
Role.where(name: 'Changeset reader').destroy_all

changeset = repository.changesets.find_by(comments: 'Adds a changelog')
issue = project.issues.order(:id).first
changeset.issues << issue unless changeset.issues.include?(issue)

puts "repository #{repository.id} identifier=#{repository.identifier} changesets=#{repository.changesets.count}"
puts "revision   /projects/#{project.identifier}/repository/#{repository.identifier_param}/revisions/#{changeset.revision}"
puts "issue      /issues/#{issue.id}"
puts "reader     norepo / GEOxyzDev123! (role #{role.name}, no view_changesets)"
puts "branches   #{repository.scm.branches.map(&:to_s).join(', ')}"
