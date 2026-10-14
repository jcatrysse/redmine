# Run with `bin/rails runner` on a database migrated up to 20250611092227:
# puts in the webhook tables, schema_migrations rows and settings that a
# 5.1-stable-GEOxyz production database carries (commits 25220b45d, cf826e3fd,
# 17528437d), with one webhook, two project links and three tracker links -
# the counts of the upgrade rehearsal of 2026-10-14.
c = ActiveRecord::Base.connection
c.create_table :webhooks do |t|
  t.references :user, :null => false
  t.string :url, :limit => 2000, :null => false
  t.string :secret, :limit => 255
  t.boolean :active, :default => true, :null => false
  t.text :events
  t.timestamps
end
c.create_table :projects_webhooks, :id => false do |t|
  t.references :project, :null => false
  t.references :webhook, :null => false
end
c.add_index :projects_webhooks, [:project_id, :webhook_id], :unique => true, :name => 'index_projects_webhooks_on_project_and_webhook'
c.create_table :trackers_webhooks, :id => false do |t|
  t.references :tracker, :null => false
  t.references :webhook, :null => false
end
c.add_index :trackers_webhooks, [:tracker_id, :webhook_id], :unique => true, :name => 'index_trackers_webhooks_on_tracker_and_webhook'
sm = c.pool.schema_migration
%w(20231120120000 20231120120100 20231120120200).each {|v| sm.create_version(v)}

now = c.quote(Time.now.utc)
c.execute "INSERT INTO webhooks (id, user_id, url, secret, active, events, created_at, updated_at) VALUES " \
          "(3, 1, 'https://hooks.nonexistent.invalid/redmine', 's3cret', #{c.quoted_true}, " \
          "#{c.quote(%w(issue.created issue.updated issue.closed).to_yaml)}, #{now}, #{now})"
c.execute "INSERT INTO projects_webhooks (project_id, webhook_id) VALUES (1, 3), (2, 3)"
c.execute "INSERT INTO trackers_webhooks (tracker_id, webhook_id) VALUES (1, 3), (2, 3), (3, 3)"
c.reset_pk_sequence!('webhooks') if c.respond_to?(:reset_pk_sequence!)
{
  'display_under_single_revision' => '1',
  'display_under_associated_revisions' => '1',
  'display_revision_branches_regex_enable' => '1',
  'display_revision_branches_enable_regex_delimiters' => "^dependabot/\nwip",
  'search_token_limit' => '0'
}.each {|name, value| c.execute "INSERT INTO settings (name, value) VALUES (#{c.quote(name)}, #{c.quote(value)})"}
puts "seeded 5.1 state: webhooks=#{c.select_value('SELECT COUNT(*) FROM webhooks')}"
